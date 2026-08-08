//// Build the AsyncAPI codegen IR from a parsed `Document`.
////
//// Resolves `$ref`s between operations, channels and messages, and hands every
//// payload schema to nori (`parse_schema` → `schema_to_typedef` /
//// `schema_to_typeref`) so the JSON-Schema engine is never re-implemented here.

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import nori
import nori/codegen/ir as nori_ir
import nori/codegen/naming
import nori/schema
import nori_asyncapi/document.{
  type Document, type Message, type MessageOrRef, type Operation,
}
import nori_asyncapi/ir

/// Build the IR from a document.
pub fn build(doc: Document) -> ir.AsyncCodegenIR {
  // Named types from components/schemas.
  let component_types =
    doc.components.schemas
    |> dict.to_list
    |> list.filter_map(fn(pair) {
      let #(name, dyn) = pair
      case schema_of(dyn) {
        Ok(s) -> Ok(nori.schema_to_typedef(type_name(name), s))
        Error(_) -> Error(Nil)
      }
    })

  // Walk operations; each yields its resolved messages plus any promoted
  // inline-payload types.
  let built =
    doc.operations
    |> dict.to_list
    |> list.map(fn(pair) {
      let #(op_id, op) = pair
      build_operation(doc, op_id, op)
    })

  // Group operations by channel so a channel carries all its operations.
  let promoted_types = list.flat_map(built, fn(b) { b.promoted })
  let channels = group_channels(doc, built)

  ir.AsyncCodegenIR(
    title: doc.info.title,
    version: doc.info.version,
    default_content_type: doc.default_content_type,
    servers: build_servers(doc),
    types: dedupe_types(list.append(component_types, promoted_types)),
    channels: channels,
  )
}

/// Drop duplicate `TypeDef`s that share a name (a payload referenced by more
/// than one operation promotes once per reference).
fn dedupe_types(types: List(nori_ir.TypeDef)) -> List(nori_ir.TypeDef) {
  types
  |> list.fold(#([], []), fn(acc, td) {
    let #(seen, out) = acc
    let name = type_def_name(td)
    case list.contains(seen, name) {
      True -> acc
      False -> #([name, ..seen], [td, ..out])
    }
  })
  |> fn(acc) { list.reverse(acc.1) }
}

fn type_def_name(td: nori_ir.TypeDef) -> String {
  case td {
    nori_ir.RecordType(name:, ..) -> name
    nori_ir.EnumType(name:, ..) -> name
    nori_ir.UnionType(name:, ..) -> name
    nori_ir.AliasType(name:, ..) -> name
  }
}

// ---------------------------------------------------------------------------
// Servers
// ---------------------------------------------------------------------------

fn build_servers(doc: Document) -> List(ir.ServerIR) {
  doc.servers
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(name, s) = pair
    ir.ServerIR(
      name: name,
      host: s.host,
      pathname: s.pathname,
      protocol: parse_protocol(s.protocol),
    )
  })
}

fn parse_protocol(p: String) -> ir.Protocol {
  case string.lowercase(p) {
    "ws" -> ir.Ws
    "wss" -> ir.Wss
    "sse" -> ir.Sse
    "http" -> ir.Http
    "https" -> ir.Https
    "kafka" -> ir.Kafka
    "nats" -> ir.Nats
    "mqtt" -> ir.Mqtt
    "amqp" -> ir.Amqp
    other -> ir.Other(other)
  }
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

/// One operation's contribution: its channel name, the operation IR, and any
/// inline payload types promoted to named `TypeDef`s.
type BuiltOp {
  BuiltOp(
    channel_name: String,
    operation: ir.OperationIR,
    promoted: List(nori_ir.TypeDef),
  )
}

fn build_operation(doc: Document, op_id: String, op: Operation) -> BuiltOp {
  let channel_name = ref_tail(op.channel_ref)

  // Resolve each message ref against the doc, build message IR + promotions.
  let resolved =
    list.map(op.message_refs, fn(ref) { resolve_message(doc, ref) })
  let messages = list.map(resolved, fn(r) { r.0 })
  let promoted = list.flat_map(resolved, fn(r) { r.1 })

  BuiltOp(
    channel_name: channel_name,
    operation: ir.OperationIR(
      operation_id: op_id,
      action: to_ir_action(op.action),
      description: op.description,
      messages: messages,
    ),
    promoted: promoted,
  )
}

fn to_ir_action(a: document.Action) -> ir.Action {
  case a {
    document.Send -> ir.Send
    document.Receive -> ir.Receive
  }
}

// ---------------------------------------------------------------------------
// Message resolution
// ---------------------------------------------------------------------------

/// Resolve a message `$ref` into a `MessageIR` plus any promoted named types.
fn resolve_message(
  doc: Document,
  ref: String,
) -> #(ir.MessageIR, List(nori_ir.TypeDef)) {
  case lookup_message(doc, ref) {
    Some(#(msg_name, msg)) -> message_to_ir(msg_name, msg)
    None ->
      // Unresolvable ref — emit an unknown-payload placeholder so codegen
      // still produces a handler rather than silently dropping the message.
      #(
        ir.MessageIR(
          name: ref_tail(ref),
          content_type: None,
          payload: nori_ir.Unknown,
          description: None,
        ),
        [],
      )
  }
}

fn message_to_ir(
  msg_name: String,
  msg: Message,
) -> #(ir.MessageIR, List(nori_ir.TypeDef)) {
  let name = case msg.name {
    Some(n) -> n
    None -> msg_name
  }
  let #(payload_ref, promoted) = case msg.payload {
    None -> #(nori_ir.Unknown, [])
    Some(dyn) -> payload_to_typeref(dyn, name)
  }
  #(
    ir.MessageIR(
      name: name,
      content_type: msg.content_type,
      payload: payload_ref,
      description: msg.description,
    ),
    promoted,
  )
}

/// Turn a raw payload schema into a `TypeRef`. Structured payloads (objects,
/// enums) are promoted to a named `TypeDef` so their shape survives; scalars
/// and arrays stay inline.
fn payload_to_typeref(
  dyn: Dynamic,
  base_name: String,
) -> #(nori_ir.TypeRef, List(nori_ir.TypeDef)) {
  case schema_of(dyn) {
    Error(_) -> #(nori_ir.Unknown, [])
    Ok(s) ->
      case is_structured(s) {
        True -> {
          let name = type_name(base_name)
          let td = nori.schema_to_typedef(name, s)
          #(nori_ir.Named(name), [td])
        }
        False -> #(nori.schema_to_typeref(s), [])
      }
  }
}

/// A schema is "structured" when it has object properties or an enum — cases
/// where a bare `TypeRef` would lose information.
fn is_structured(s: schema.Schema) -> Bool {
  case s.enum_values {
    Some(_) -> True
    None -> !dict.is_empty(s.properties)
  }
}

fn schema_of(dyn: Dynamic) -> Result(schema.Schema, Nil) {
  case nori.parse_schema(dyn) {
    Ok(s) -> Ok(s)
    Error(_) -> Error(Nil)
  }
}

// ---------------------------------------------------------------------------
// Channel grouping
// ---------------------------------------------------------------------------

fn group_channels(doc: Document, built: List(BuiltOp)) -> List(ir.ChannelIR) {
  doc.channels
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(name, ch) = pair
    let ops =
      built
      |> list.filter(fn(b) { b.channel_name == name })
      |> list.map(fn(b) { b.operation })
    ir.ChannelIR(
      name: name,
      address: option.unwrap(ch.address, name),
      description: ch.description,
      parameters: build_params(ch),
      operations: ops,
    )
  })
}

fn build_params(ch: document.Channel) -> List(ir.ChannelParam) {
  ch.parameters
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(name, p) = pair
    ir.ChannelParam(
      name: name,
      description: p.description,
      enum_values: p.enum_values,
    )
  })
}

// ---------------------------------------------------------------------------
// $ref helpers
// ---------------------------------------------------------------------------

/// Look up a message by `$ref`. Supports:
/// - `#/components/messages/Name`
/// - `#/channels/Chan/messages/Name`
fn lookup_message(doc: Document, ref: String) -> Option(#(String, Message)) {
  case ref_segments(ref) {
    ["components", "messages", name] ->
      dict.get(doc.components.messages, name)
      |> option.from_result
      |> option.map(fn(m) { #(name, m) })
    ["channels", chan, "messages", name] ->
      case dict.get(doc.channels, chan) {
        Ok(ch) ->
          case dict.get(ch.messages, name) {
            Ok(mor) -> resolve_message_or_ref(doc, name, mor)
            Error(_) -> None
          }
        Error(_) -> None
      }
    _ -> None
  }
}

fn resolve_message_or_ref(
  doc: Document,
  name: String,
  mor: MessageOrRef,
) -> Option(#(String, Message)) {
  case mor {
    document.InlineMessage(m) -> Some(#(name, m))
    document.MessageRef(ref) -> lookup_message(doc, ref)
  }
}

/// Drop the leading `#` and split a JSON pointer into path segments.
fn ref_segments(ref: String) -> List(String) {
  ref
  |> string.replace("#/", "")
  |> string.split("/")
}

/// The last segment of a `$ref` — the referenced name.
fn ref_tail(ref: String) -> String {
  case list.last(ref_segments(ref)) {
    Ok(name) -> name
    Error(_) -> ref
  }
}

/// Sanitise a spec name into a Gleam-safe type name (PascalCase-ish). Kept
/// deliberately simple; nori's own naming rules apply inside `schema_to_typedef`.
fn type_name(name: String) -> String {
  naming.to_type_name(name)
}
