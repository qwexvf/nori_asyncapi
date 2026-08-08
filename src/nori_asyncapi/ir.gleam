//// Language-agnostic codegen IR for AsyncAPI.
////
//// The async counterpart to nori's `CodegenIR`. Payload/header shapes reuse
//// nori's `TypeDef` / `TypeRef` verbatim, so a message payload and a REST
//// response body share one type model and one downstream emitter vocabulary.

import gleam/option.{type Option}
import nori/codegen/ir.{type TypeDef, type TypeRef}

/// Everything a generator needs to emit channel / message code.
pub type AsyncCodegenIR {
  AsyncCodegenIR(
    title: String,
    version: String,
    default_content_type: Option(String),
    servers: List(ServerIR),
    /// Named payload/header types, reusing nori's IR type model.
    types: List(TypeDef),
    channels: List(ChannelIR),
  )
}

/// A server with its resolved transport protocol.
pub type ServerIR {
  ServerIR(
    name: String,
    host: String,
    pathname: Option(String),
    protocol: Protocol,
  )
}

/// Transports a generator knows how to emit. Anything else lands in `Other`.
pub type Protocol {
  Ws
  Wss
  Sse
  Http
  Https
  Kafka
  Nats
  Mqtt
  Amqp
  Other(String)
}

/// A channel with the operations that act on it.
pub type ChannelIR {
  ChannelIR(
    name: String,
    address: String,
    description: Option(String),
    parameters: List(ChannelParam),
    operations: List(OperationIR),
  )
}

/// A channel address variable, e.g. the `{id}` in `lobby/{id}/chat`.
pub type ChannelParam {
  ChannelParam(
    name: String,
    description: Option(String),
    enum_values: List(String),
  )
}

/// An operation: a direction plus the messages it carries.
pub type OperationIR {
  OperationIR(
    operation_id: String,
    action: Action,
    description: Option(String),
    messages: List(MessageIR),
  )
}

/// Direction from the application's point of view.
pub type Action {
  Send
  Receive
}

/// A message: a name plus a reference into `types` for its payload.
pub type MessageIR {
  MessageIR(
    name: String,
    content_type: Option(String),
    /// Reference into `AsyncCodegenIR.types`, or an inline primitive/array.
    payload: TypeRef,
    description: Option(String),
  )
}
