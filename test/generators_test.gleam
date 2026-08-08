import fixtures
import gleam/string
import gleeunit/should
import nori_asyncapi

fn ts_of(spec: String) -> String {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.build_ir(doc) |> nori_asyncapi.generate_typescript
}

fn gleam_of(spec: String) -> String {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.generate_gleam_handlers(
    nori_asyncapi.build_ir(doc),
    "generated/types",
  )
}

fn has(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}

// --- TypeScript ---

pub fn ts_emits_payload_interface_test() {
  let ts = ts_of(fixtures.ws_counts)
  has(ts, "export interface CountUpdate {") |> should.be_true
  has(ts, "serverId: string;") |> should.be_true
  has(ts, "players: number;") |> should.be_true
  // optional field carries `?`
  has(ts, "map?: string;") |> should.be_true
}

pub fn ts_server_send_becomes_client_subscribe_test() {
  // server `send` (onCounts) → client subscribes with an on* method
  let ts = ts_of(fixtures.ws_counts)
  has(ts, "class CountsChannel {") |> should.be_true
  has(ts, "onCountUpdate(handler: (msg: CountUpdate) => void): () => void")
  |> should.be_true
  has(ts, "this.transport.subscribe") |> should.be_true
}

pub fn ts_server_receive_becomes_client_publish_test() {
  // server `receive` (onPing) → client publishes with a send* method
  let ts = ts_of(fixtures.inline_primitive)
  has(ts, "sendPing(msg: string): void") |> should.be_true
  has(ts, "this.transport.send(JSON.stringify(msg))") |> should.be_true
}

pub fn ts_ws_server_connects_over_websocket_test() {
  let ts = ts_of(fixtures.ws_counts)
  has(ts, "new WebSocketTransport(`${baseUrl}/server.counts`)")
  |> should.be_true
}

pub fn ts_sse_server_connects_over_eventsource_test() {
  let ts = ts_of(fixtures.sse_feed)
  has(ts, "new EventSourceTransport(") |> should.be_true
}

pub fn ts_address_params_typed_in_connect_test() {
  let spec =
    "asyncapi: 3.0.0
info:
  title: P
  version: 1.0.0
servers:
  s:
    host: h
    protocol: ws
channels:
  chat:
    address: lobby/{lobbyId}/chat
    parameters:
      lobbyId:
        description: id
operations: {}
"
  let ts = ts_of(spec)
  has(ts, "connect(baseUrl: string, params: { lobbyId: string })")
  |> should.be_true
  has(ts, "lobby/${params.lobbyId}/chat") |> should.be_true
}

pub fn ts_bidirectional_channel_has_both_directions_test() {
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let ts = nori_asyncapi.build_ir(doc) |> nori_asyncapi.generate_typescript
  // one RoomChannel class carrying publishes AND subscribes
  has(ts, "class RoomChannel {") |> should.be_true
  has(ts, "sendChatSent(msg: ChatSent): void") |> should.be_true
  has(ts, "onPresence(handler: (msg: Presence) => void): () => void")
  |> should.be_true
  // enum $ref resolved into a union type
  has(ts, "export type PresenceStatus =") |> should.be_true
}

fn gateway_of(spec: String) -> String {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.build_ir(doc) |> nori_asyncapi.generate_typescript_gateway
}

pub fn gateway_multiplexes_over_one_client_test() {
  let ts = gateway_of(fixtures.ws_counts)
  // single client, envelope publish/subscribe helpers
  has(ts, "export class GatewayClient {") |> should.be_true
  has(ts, "JSON.stringify({ type, payload })") |> should.be_true
  // server `send` (onCounts) -> client subscribe by message type
  has(ts, "onCountUpdate(handler: (msg: CountUpdate) => void): () => void")
  |> should.be_true
  has(ts, "this.subscribe(\"CountUpdate\"") |> should.be_true
}

pub fn gateway_publish_for_client_send_test() {
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let ts =
    nori_asyncapi.build_ir(doc) |> nori_asyncapi.generate_typescript_gateway
  // chat's sendChat is a server receive -> client publishes with envelope type
  has(ts, "sendChatSent(msg: ChatSent): void") |> should.be_true
  has(ts, "this.publish(\"ChatSent\", msg)") |> should.be_true
}

fn stores_of(spec: String) -> String {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.build_ir(doc)
  |> nori_asyncapi.generate_typescript_stores("./client")
}

pub fn ts_client_has_no_store_test() {
  // stores live in their own module, never in the client
  let ts = ts_of(fixtures.ws_counts)
  has(ts, "Store(") |> should.be_false
}

pub fn ts_subscribe_message_emits_store_factory_test() {
  let stores = stores_of(fixtures.ws_counts)
  has(stores, "export function createCountUpdateStore(baseUrl: string) {")
  |> should.be_true
  has(stores, "subscribe(onChange: () => void): () => void") |> should.be_true
  has(stores, "getSnapshot(): CountUpdate | undefined") |> should.be_true
  // imports channel + named payload type from the client module
  has(stores, "import { CountsChannel, type CountUpdate }")
  |> should.be_true
}

pub fn ts_publish_only_channel_has_no_store_test() {
  // inline_primitive's onPing is a client publish → no store factory
  let stores = stores_of(fixtures.inline_primitive)
  has(stores, "createStore") |> should.be_false
  has(stores, "No subscribe messages") |> should.be_true
}

pub fn ts_array_payload_renders_as_array_test() {
  let ts = ts_of(fixtures.array_and_enum)
  has(ts, "onBatch(handler: (msg: string[]) => void)") |> should.be_true
}

pub fn ts_enum_renders_as_union_test() {
  let ts = ts_of(fixtures.array_and_enum)
  has(ts, "\"active\"") |> should.be_true
  has(ts, "\"closed\"") |> should.be_true
}

// --- Gleam server dispatcher ---

fn server_of(spec: String) -> String {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  nori_asyncapi.generate_gleam_server(
    nori_asyncapi.build_ir(doc),
    "generated/types",
  )
}

pub fn server_receive_becomes_handler_test() {
  // chat's sendChat is a server receive → handler callback + dispatch arm
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let code =
    nori_asyncapi.generate_gleam_server(
      nori_asyncapi.build_ir(doc),
      "generated/types",
    )
  has(code, "on_chat_sent: fn(types.ChatSent) -> Nil") |> should.be_true
  has(code, "\"ChatSent\" ->") |> should.be_true
  has(code, "types.chat_sent_decoder()") |> should.be_true
}

pub fn server_send_becomes_encoder_test() {
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let code =
    nori_asyncapi.generate_gleam_server(
      nori_asyncapi.build_ir(doc),
      "generated/types",
    )
  has(code, "pub fn send_presence(msg: types.Presence) -> String {")
  |> should.be_true
  has(code, "types.encode_presence(msg)") |> should.be_true
}

pub fn server_no_receive_has_no_dispatch_test() {
  // ws_counts only has a send op → no Handlers/dispatch, just an encoder
  let code = server_of(fixtures.ws_counts)
  has(code, "pub fn dispatch(") |> should.be_false
  has(code, "No `receive` operations") |> should.be_true
  has(code, "pub fn send_count_update(") |> should.be_true
}

// --- Gleam handlers ---

pub fn gleam_send_op_emits_emitter_test() {
  let code = gleam_of(fixtures.ws_counts)
  has(code, "pub fn emit_on_counts(msg: types.CountUpdate) -> Nil {")
  |> should.be_true
}

pub fn gleam_receive_op_emits_handler_test() {
  let code = gleam_of(fixtures.inline_primitive)
  has(code, "pub fn handle_on_ping(msg: String) -> Nil {") |> should.be_true
}

pub fn gleam_channel_banner_test() {
  let code = gleam_of(fixtures.ws_counts)
  has(code, "// channel: server.counts") |> should.be_true
}
