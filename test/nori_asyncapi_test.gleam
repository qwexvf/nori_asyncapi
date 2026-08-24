import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import nori_asyncapi
import nori_asyncapi/ir

pub fn main() {
  gleeunit.main()
}

const spec = "asyncapi: 3.0.0
info:
  title: RT
  version: 1.0.0
servers:
  rt:
    host: rt.example.com
    protocol: ws
channels:
  counts:
    address: server.counts
    messages:
      countUpdate:
        $ref: '#/components/messages/CountUpdate'
operations:
  onCounts:
    action: send
    channel:
      $ref: '#/channels/counts'
    messages:
      - $ref: '#/channels/counts/messages/countUpdate'
components:
  messages:
    CountUpdate:
      name: CountUpdate
      payload:
        type: object
        required:
          - serverId
          - players
        properties:
          serverId:
            type: string
          players:
            type: integer
"

pub fn parse_yaml_test() {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  doc.info.title |> should.equal("RT")
  doc.asyncapi |> should.equal("3.0.0")
}

pub fn build_ir_test() {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  let built = nori_asyncapi.build_ir(doc)

  built.title |> should.equal("RT")
  list.length(built.channels) |> should.equal(1)

  // protocol resolved to ws
  let assert Ok(server) = list.first(built.servers)
  server.protocol |> should.equal(ir.Ws)

  // channel carries the send operation
  let assert Ok(channel) = list.first(built.channels)
  channel.address |> should.equal("server.counts")
  let assert Ok(op) = list.first(channel.operations)
  op.action |> should.equal(ir.Send)

  // payload promoted to a named type in `types`
  list.length(built.types) |> should.not_equal(0)
}

pub fn typescript_gen_test() {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  let ts = nori_asyncapi.build_ir(doc) |> nori_asyncapi.generate_typescript

  string.contains(ts, "export interface") |> should.be_true
  string.contains(ts, "serverId") |> should.be_true
  string.contains(ts, "class CountsChannel {") |> should.be_true
  string.contains(ts, "onCountUpdate(handler:") |> should.be_true
  // ws server → WebSocket transport in connect
  string.contains(ts, "new WebSocketTransport(") |> should.be_true
}

pub fn gleam_handlers_gen_test() {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec)
  let code =
    nori_asyncapi.generate_gleam_handlers(
      nori_asyncapi.build_ir(doc),
      "generated/types",
    )

  // send-only spec → no handler stubs, no dead `emit_*`, no unused imports
  string.contains(code, "emit_") |> should.be_false
  string.contains(code, "No `receive` operations") |> should.be_true
  string.contains(code, "import gleam/dict") |> should.be_false
  string.contains(code, "import gleam/dynamic") |> should.be_false
  string.contains(code, "import gleam/option") |> should.be_false
}
