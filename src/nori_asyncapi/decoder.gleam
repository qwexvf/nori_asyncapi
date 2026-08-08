//// Decoders for AsyncAPI 3.x documents (from a `Dynamic` produced by the YAML
//// or JSON bridge). Uses `gleam/dynamic/decode`.
////
//// Message payloads/headers are captured raw as `Dynamic` — they are JSON
//// Schema and get decoded by `nori.parse_schema` downstream, so the schema
//// engine is never duplicated here.

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type DecodeError, type Decoder}
import gleam/option.{type Option, None}
import nori_asyncapi/document.{
  type Action, type Channel, type Components, type Document, type Info,
  type Message, type MessageOrRef, type Operation, type Parameter, type Server,
  Channel, Components, Document, Info, InlineMessage, Message, MessageRef,
  Operation, Parameter, Server,
}

/// Decode an AsyncAPI document from a `Dynamic`.
pub fn decode_document(dyn: Dynamic) -> Result(Document, List(DecodeError)) {
  decode.run(dyn, document_decoder())
}

fn opt(d: Decoder(a)) -> Decoder(Option(a)) {
  decode.optional(d)
}

/// Decoder for the AsyncAPI root object.
pub fn document_decoder() -> Decoder(Document) {
  use asyncapi <- decode.field("asyncapi", decode.string)
  use id <- decode.optional_field("id", None, opt(decode.string))
  use info <- decode.field("info", info_decoder())
  use default_content_type <- decode.optional_field(
    "defaultContentType",
    None,
    opt(decode.string),
  )
  use servers <- decode.optional_field(
    "servers",
    dict.new(),
    decode.dict(decode.string, server_decoder()),
  )
  use channels <- decode.optional_field(
    "channels",
    dict.new(),
    decode.dict(decode.string, channel_decoder()),
  )
  use operations <- decode.optional_field(
    "operations",
    dict.new(),
    decode.dict(decode.string, operation_decoder()),
  )
  use components <- decode.optional_field(
    "components",
    document.empty_components(),
    components_decoder(),
  )
  decode.success(Document(
    asyncapi: asyncapi,
    id: id,
    info: info,
    default_content_type: default_content_type,
    servers: servers,
    channels: channels,
    operations: operations,
    components: components,
  ))
}

fn info_decoder() -> Decoder(Info) {
  use title <- decode.field("title", decode.string)
  use version <- decode.field("version", decode.string)
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  decode.success(Info(title: title, version: version, description: description))
}

fn server_decoder() -> Decoder(Server) {
  use host <- decode.field("host", decode.string)
  use protocol <- decode.field("protocol", decode.string)
  use pathname <- decode.optional_field("pathname", None, opt(decode.string))
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  decode.success(Server(
    host: host,
    protocol: protocol,
    pathname: pathname,
    description: description,
  ))
}

fn channel_decoder() -> Decoder(Channel) {
  use address <- decode.optional_field("address", None, opt(decode.string))
  use title <- decode.optional_field("title", None, opt(decode.string))
  use summary <- decode.optional_field("summary", None, opt(decode.string))
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  use messages <- decode.optional_field(
    "messages",
    dict.new(),
    decode.dict(decode.string, message_or_ref_decoder()),
  )
  use parameters <- decode.optional_field(
    "parameters",
    dict.new(),
    decode.dict(decode.string, parameter_decoder()),
  )
  use servers <- decode.optional_field(
    "servers",
    [],
    decode.list(ref_object_decoder()),
  )
  decode.success(Channel(
    address: address,
    title: title,
    summary: summary,
    description: description,
    messages: messages,
    parameters: parameters,
    servers: servers,
  ))
}

fn operation_decoder() -> Decoder(Operation) {
  use action_str <- decode.field("action", decode.string)
  use channel_ref <- decode.field("channel", ref_object_decoder())
  use title <- decode.optional_field("title", None, opt(decode.string))
  use summary <- decode.optional_field("summary", None, opt(decode.string))
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  use message_refs <- decode.optional_field(
    "messages",
    [],
    decode.list(ref_object_decoder()),
  )
  decode.success(Operation(
    action: action_decoder_value(action_str),
    channel_ref: channel_ref,
    title: title,
    summary: summary,
    description: description,
    message_refs: message_refs,
  ))
}

fn action_decoder_value(s: String) -> Action {
  document.action_from_string(s)
}

fn message_decoder() -> Decoder(Message) {
  use name <- decode.optional_field("name", None, opt(decode.string))
  use title <- decode.optional_field("title", None, opt(decode.string))
  use summary <- decode.optional_field("summary", None, opt(decode.string))
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  use content_type <- decode.optional_field(
    "contentType",
    None,
    opt(decode.string),
  )
  use payload <- decode.optional_field("payload", None, opt(decode.dynamic))
  use headers <- decode.optional_field("headers", None, opt(decode.dynamic))
  decode.success(Message(
    name: name,
    title: title,
    summary: summary,
    description: description,
    content_type: content_type,
    payload: payload,
    headers: headers,
  ))
}

fn message_or_ref_decoder() -> Decoder(MessageOrRef) {
  decode.one_of(decode.map(ref_object_decoder(), MessageRef), or: [
    decode.map(message_decoder(), InlineMessage),
  ])
}

fn parameter_decoder() -> Decoder(Parameter) {
  use description <- decode.optional_field(
    "description",
    None,
    opt(decode.string),
  )
  use enum_values <- decode.optional_field(
    "enum",
    [],
    decode.list(decode.string),
  )
  use default <- decode.optional_field("default", None, opt(decode.string))
  use location <- decode.optional_field("location", None, opt(decode.string))
  decode.success(Parameter(
    description: description,
    enum_values: enum_values,
    default: default,
    location: location,
  ))
}

fn components_decoder() -> Decoder(Components) {
  use messages <- decode.optional_field(
    "messages",
    dict.new(),
    decode.dict(decode.string, message_decoder()),
  )
  use schemas <- decode.optional_field(
    "schemas",
    dict.new(),
    decode.dict(decode.string, decode.dynamic),
  )
  use channels <- decode.optional_field(
    "channels",
    dict.new(),
    decode.dict(decode.string, channel_decoder()),
  )
  use parameters <- decode.optional_field(
    "parameters",
    dict.new(),
    decode.dict(decode.string, parameter_decoder()),
  )
  decode.success(Components(
    messages: messages,
    schemas: schemas,
    channels: channels,
    parameters: parameters,
  ))
}

/// Decode a `{ "$ref": "..." }` object down to the ref string.
fn ref_object_decoder() -> Decoder(String) {
  use ref <- decode.field("$ref", decode.string)
  decode.success(ref)
}
