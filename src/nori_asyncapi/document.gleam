//// AsyncAPI 3.x document model.
////
//// Root object of an AsyncAPI spec. Mirrors the parts of the 3.1.0 spec the
//// generators need: info, servers, channels, operations, components. Message
//// payloads are kept as raw `Dynamic` — they are plain JSON Schema and get
//// handed to `nori.parse_schema` at IR-build time so the schema engine stays
//// single-sourced in nori.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

/// The root AsyncAPI object.
pub type Document {
  Document(
    asyncapi: String,
    id: Option(String),
    info: Info,
    default_content_type: Option(String),
    servers: Dict(String, Server),
    channels: Dict(String, Channel),
    operations: Dict(String, Operation),
    components: Components,
  )
}

/// Info object — API metadata.
pub type Info {
  Info(title: String, version: String, description: Option(String))
}

/// Server object. `protocol` drives which transport a generator emits.
pub type Server {
  Server(
    host: String,
    protocol: String,
    pathname: Option(String),
    description: Option(String),
  )
}

/// Channel object — a named address messages flow over.
pub type Channel {
  Channel(
    address: Option(String),
    title: Option(String),
    summary: Option(String),
    description: Option(String),
    /// Named messages available on this channel. Value is a message OR a ref.
    messages: Dict(String, MessageOrRef),
    /// Channel-level parameters (address templating, e.g. `{id}`).
    parameters: Dict(String, Parameter),
    /// `$ref` strings of servers this channel is restricted to.
    servers: List(String),
  )
}

/// Operation object — an action (send/receive) bound to a channel.
pub type Operation {
  Operation(
    action: Action,
    /// `$ref` to the channel this operation acts on.
    channel_ref: String,
    title: Option(String),
    summary: Option(String),
    description: Option(String),
    /// `$ref` strings of the messages this operation carries.
    message_refs: List(String),
  )
}

/// Operation action — direction from the application's point of view.
pub type Action {
  Send
  Receive
}

/// Message object. `payload` is raw JSON Schema (Dynamic) resolved later.
pub type Message {
  Message(
    name: Option(String),
    title: Option(String),
    summary: Option(String),
    description: Option(String),
    content_type: Option(String),
    payload: Option(Dynamic),
    headers: Option(Dynamic),
  )
}

/// A message that is either inline or a `$ref`.
pub type MessageOrRef {
  InlineMessage(Message)
  MessageRef(String)
}

/// Parameter object — a channel address variable.
pub type Parameter {
  Parameter(
    description: Option(String),
    enum_values: List(String),
    default: Option(String),
    location: Option(String),
  )
}

/// Reusable components. Only the buckets the generators consume are modelled;
/// the rest of the spec's component buckets are ignored for now.
pub type Components {
  Components(
    messages: Dict(String, Message),
    /// Raw JSON Schema subtrees, resolved through `nori.parse_schema`.
    schemas: Dict(String, Dynamic),
    channels: Dict(String, Channel),
    parameters: Dict(String, Parameter),
  )
}

/// An empty document with only the required fields set.
pub fn new(asyncapi: String, info: Info) -> Document {
  Document(
    asyncapi: asyncapi,
    id: option.None,
    info: info,
    default_content_type: option.None,
    servers: dict.new(),
    channels: dict.new(),
    operations: dict.new(),
    components: empty_components(),
  )
}

/// An empty components bag.
pub fn empty_components() -> Components {
  Components(
    messages: dict.new(),
    schemas: dict.new(),
    channels: dict.new(),
    parameters: dict.new(),
  )
}

/// Parse an action string. Unknown values default to `Receive` (server pushes
/// nothing) so a malformed spec fails safe rather than emitting a sender.
pub fn action_from_string(s: String) -> Action {
  case s {
    "send" -> Send
    _ -> Receive
  }
}
