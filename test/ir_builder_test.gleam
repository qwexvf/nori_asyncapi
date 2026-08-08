import fixtures
import gleam/list
import gleam/option
import gleeunit/should
import nori/codegen/ir as nori_ir
import nori_asyncapi
import nori_asyncapi/ir

fn ir_of(spec: String) -> ir.AsyncCodegenIR {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.build_ir(doc)
}

fn find_channel(spec: ir.AsyncCodegenIR, name: String) -> ir.ChannelIR {
  let assert Ok(ch) = list.find(spec.channels, fn(c) { c.name == name })
  ch
}

fn find_type(spec: ir.AsyncCodegenIR, name: String) -> nori_ir.TypeDef {
  let assert Ok(td) =
    list.find(spec.types, fn(t) {
      case t {
        nori_ir.RecordType(name: n, ..) -> n == name
        nori_ir.EnumType(name: n, ..) -> n == name
        nori_ir.UnionType(name: n, ..) -> n == name
        nori_ir.AliasType(name: n, ..) -> n == name
      }
    })
  td
}

pub fn ws_protocol_resolved_test() {
  let spec = ir_of(fixtures.ws_counts)
  let assert Ok(server) = list.first(spec.servers)
  server.protocol |> should.equal(ir.Ws)
  server.host |> should.equal("rt.example.com")
}

pub fn sse_protocol_resolved_test() {
  let spec = ir_of(fixtures.sse_feed)
  let assert Ok(server) = list.first(spec.servers)
  server.protocol |> should.equal(ir.Sse)
}

pub fn send_operation_direction_test() {
  let spec = ir_of(fixtures.ws_counts)
  let ch = find_channel(spec, "counts")
  let assert Ok(op) = list.first(ch.operations)
  op.action |> should.equal(ir.Send)
  op.operation_id |> should.equal("onCounts")
}

pub fn receive_operation_direction_test() {
  let spec = ir_of(fixtures.inline_primitive)
  let ch = find_channel(spec, "pings")
  let assert Ok(op) = list.first(ch.operations)
  op.action |> should.equal(ir.Receive)
}

pub fn object_payload_promoted_to_named_type_test() {
  let spec = ir_of(fixtures.ws_counts)
  let ch = find_channel(spec, "counts")
  let assert Ok(op) = list.first(ch.operations)
  let assert Ok(msg) = list.first(op.messages)
  // object payload → Named ref into types
  msg.payload |> should.equal(nori_ir.Named("CountUpdate"))

  // and that named type is a record with the right fields
  case find_type(spec, "CountUpdate") {
    nori_ir.RecordType(fields:, ..) -> {
      let names = list.map(fields, fn(f) { f.name })
      list.contains(names, "serverId") |> should.be_true
      list.contains(names, "players") |> should.be_true
    }
    _ -> should.fail()
  }
}

pub fn required_vs_optional_fields_test() {
  let spec = ir_of(fixtures.ws_counts)
  case find_type(spec, "CountUpdate") {
    nori_ir.RecordType(fields:, ..) -> {
      let assert Ok(server_id) =
        list.find(fields, fn(f) { f.name == "serverId" })
      server_id.required |> should.be_true
      let assert Ok(map) = list.find(fields, fn(f) { f.name == "map" })
      map.required |> should.be_false
    }
    _ -> should.fail()
  }
}

pub fn primitive_payload_stays_inline_test() {
  let spec = ir_of(fixtures.inline_primitive)
  let ch = find_channel(spec, "pings")
  let assert Ok(op) = list.first(ch.operations)
  let assert Ok(msg) = list.first(op.messages)
  // string payload → inline primitive, NOT promoted
  msg.payload |> should.equal(nori_ir.Primitive(nori_ir.PString))
}

pub fn array_payload_stays_inline_test() {
  let spec = ir_of(fixtures.array_and_enum)
  let ch = find_channel(spec, "events")
  let assert Ok(op) =
    list.find(ch.operations, fn(o) { o.operation_id == "onBatch" })
  let assert Ok(msg) = list.first(op.messages)
  msg.payload |> should.equal(nori_ir.Array(nori_ir.Primitive(nori_ir.PString)))
}

pub fn enum_payload_promoted_test() {
  let spec = ir_of(fixtures.array_and_enum)
  // status message payload is a root enum → promoted EnumType
  case find_type(spec, "Status") {
    nori_ir.EnumType(variants:, ..) -> list.length(variants) |> should.equal(2)
    _ -> should.fail()
  }
}

pub fn multi_operation_channel_test() {
  let spec = ir_of(fixtures.array_and_enum)
  let ch = find_channel(spec, "events")
  // both onBatch and onStatus land under the one channel
  list.length(ch.operations) |> should.equal(2)
}

pub fn channel_parameters_test() {
  let spec =
    "asyncapi: 3.0.0
info:
  title: P
  version: 1.0.0
channels:
  chat:
    address: lobby/{id}/chat
    parameters:
      id:
        description: lobby id
operations: {}
"
  let built = ir_of(spec)
  let ch = find_channel(built, "chat")
  let assert Ok(param) = list.first(ch.parameters)
  param.name |> should.equal("id")
  param.description |> should.equal(option.Some("lobby id"))
}

pub fn dangling_message_ref_placeholder_test() {
  let spec = ir_of(fixtures.dangling_ref)
  let ch = find_channel(spec, "c")
  let assert Ok(op) = list.first(ch.operations)
  let assert Ok(msg) = list.first(op.messages)
  // unresolvable ref → placeholder with unknown payload, not a crash
  msg.name |> should.equal("DoesNotExist")
  msg.payload |> should.equal(nori_ir.Unknown)
}
