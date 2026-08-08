//// Compiles generated Gleam with the real Gleam compiler.
////
//// String assertions cannot catch output that is well-formed text but invalid
//// Gleam (bad imports, type refs that do not resolve, codec mismatches). This
//// test writes the generated types + handler modules into a scratch project
//// under build/ and shells out to `gleam build` there.
////
//// Needs the `gleam` binary on PATH, and network on first run to fetch the
//// scratch project's deps.

import gleam/string
import nori_asyncapi
import simplifile

const project_dir = "build/compile_check"

const gen_dir = "build/compile_check/src/generated"

const scratch_gleam_toml = "name = \"compile_check\"
version = \"0.0.0\"
gleam = \">= 1.15.0\"

[dependencies]
gleam_stdlib = \">= 0.44.0 and < 2.0.0\"
gleam_json = \">= 3.1.0 and < 4.0.0\"
"

@external(erlang, "compile_check_ffi", "shell")
@external(javascript, "./compile_check_ffi.mjs", "shell")
fn shell(command: String) -> String

pub fn ws_output_compiles_test() {
  should_compile(fixtures_ws())
}

pub fn sse_output_compiles_test() {
  should_compile(fixtures_sse())
}

pub fn array_and_enum_output_compiles_test() {
  should_compile(fixtures_array_and_enum())
}

/// The full bidirectional chat example: one channel with both client-publish
/// and client-subscribe messages, a $ref'd enum, and address params.
pub fn chat_example_output_compiles_test() {
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let spec = nori_asyncapi.build_ir(doc)
  let types = nori_asyncapi.generate_gleam_types(spec)
  let handlers = nori_asyncapi.generate_gleam_handlers(spec, "generated/types")
  write_project(types, handlers)
  let output =
    shell("cd " <> project_dir <> " && gleam build 2>&1; echo __EXIT:$?")
  case string.contains(output, "__EXIT:0") {
    True -> Nil
    False -> panic as { "chat example failed to compile:\n" <> output }
  }
}

// --- helpers ---

fn should_compile(spec_yaml: String) -> Nil {
  let assert Ok(doc) = nori_asyncapi.parse_yaml(spec_yaml)
  let spec = nori_asyncapi.build_ir(doc)
  let types = nori_asyncapi.generate_gleam_types(spec)
  let handlers = nori_asyncapi.generate_gleam_handlers(spec, "generated/types")

  write_project(types, handlers)

  let output =
    shell("cd " <> project_dir <> " && gleam build 2>&1; echo __EXIT:$?")
  case string.contains(output, "__EXIT:0") {
    True -> Nil
    False -> panic as { "generated code failed to compile:\n" <> output }
  }
}

fn write_project(types: String, handlers: String) -> Nil {
  let _ = simplifile.delete(gen_dir)
  let assert Ok(_) = simplifile.create_directory_all(gen_dir)
  let assert Ok(_) =
    simplifile.write(project_dir <> "/gleam.toml", scratch_gleam_toml)
  let assert Ok(_) = simplifile.write(gen_dir <> "/types.gleam", types)
  let assert Ok(_) = simplifile.write(gen_dir <> "/handlers.gleam", handlers)
  Nil
}

/// The server dispatcher (types + server) compiles, including the decoders and
/// encoders it calls in the types module.
pub fn server_dispatcher_compiles_test() {
  let assert Ok(doc) = nori_asyncapi.parse_file("examples/chat.yaml")
  let spec = nori_asyncapi.build_ir(doc)
  let _ = simplifile.delete(gen_dir)
  let assert Ok(_) = simplifile.create_directory_all(gen_dir)
  let assert Ok(_) =
    simplifile.write(project_dir <> "/gleam.toml", scratch_gleam_toml)
  let assert Ok(_) =
    simplifile.write(
      gen_dir <> "/types.gleam",
      nori_asyncapi.generate_gleam_types(spec),
    )
  let assert Ok(_) =
    simplifile.write(
      gen_dir <> "/server.gleam",
      nori_asyncapi.generate_gleam_server(spec, "generated/types"),
    )
  let output =
    shell("cd " <> project_dir <> " && gleam build 2>&1; echo __EXIT:$?")
  case string.contains(output, "__EXIT:0") {
    True -> Nil
    False -> panic as { "server dispatcher failed to compile:\n" <> output }
  }
}

// Fixtures duplicated as functions so this module is self-contained (the shared
// `fixtures` module holds the same specs).

fn fixtures_ws() -> String {
  "asyncapi: 3.0.0
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
        properties:
          serverId:
            type: string
          players:
            type: integer
          map:
            type: string
"
}

fn fixtures_sse() -> String {
  "asyncapi: 3.0.0
info:
  title: Feed
  version: 2.0.0
servers:
  feed:
    host: feed.example.com
    protocol: sse
channels:
  ticks:
    address: ticks
    messages:
      tick:
        payload:
          type: object
          properties:
            value:
              type: number
operations:
  onTick:
    action: receive
    channel:
      $ref: '#/channels/ticks'
    messages:
      - $ref: '#/channels/ticks/messages/tick'
"
}

fn fixtures_array_and_enum() -> String {
  "asyncapi: 3.0.0
info:
  title: Shapes
  version: 1.0.0
channels:
  events:
    address: events
    messages:
      batch:
        payload:
          type: array
          items:
            type: string
      status:
        payload:
          type: string
          enum:
            - active
            - closed
operations:
  onBatch:
    action: send
    channel:
      $ref: '#/channels/events'
    messages:
      - $ref: '#/channels/events/messages/batch'
  onStatus:
    action: send
    channel:
      $ref: '#/channels/events'
    messages:
      - $ref: '#/channels/events/messages/status'
"
}
