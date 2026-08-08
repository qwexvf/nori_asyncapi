# nori_asyncapi

AsyncAPI 3.x code generation for Gleam. A satellite of [nori](https://github.com/qwexvf/nori).

Parses AsyncAPI specs (YAML or JSON) into a typed document, builds a codegen IR
whose message payloads reuse nori's type model, and emits a typed TypeScript
client and Gleam server handlers from the same spec.

- **One schema engine.** Message payloads are plain JSON Schema, so they are
  handed to nori (`parse_schema` → `schema_to_typedef` / `schema_to_typeref`)
  rather than re-implementing schema handling. A message payload and a REST
  response body become the same generated type.
- **Client-correct TypeScript.** AsyncAPI `action` is written from the server's
  point of view; the TS generator inverts it, so a server `send` becomes a client
  `on*` subscription and a server `receive` becomes a client `send*` publish.
- **Verified output.** Generated Gleam is compiled with the real compiler in the
  test suite; generated TypeScript type-checks under `tsc --strict`.

## Install

```sh
gleam add nori_asyncapi
```

Requires `nori >= 1.5.0` (pulled in automatically).

## Quick start

```sh
# from a config file (auto-detected as ./asyncapi.config.yaml)
gleam run -m nori_asyncapi/cli -- generate

# or positional args, everything into one directory
gleam run -m nori_asyncapi/cli -- generate examples/chat.yaml ./out --stores
```

## What gets generated

From an AsyncAPI spec with a channel, messages, and operations:

| file | target | contents |
|------|--------|----------|
| `client.ts` | frontend | payload interfaces, a `Transport` runtime (WebSocket + SSE), one typed class per channel |
| `stores.ts` | frontend (opt-in) | `useSyncExternalStore`-compatible observable per subscribe message |
| `types.gleam` | backend | payload records/enums + JSON codecs (via nori's emitter) |
| `handlers.gleam` | backend | `handle_*` stubs (client→server) and `emit_*` helpers (server→client) |

### Example

Spec (`examples/chat.yaml`) — a bidirectional room channel:

```yaml
channels:
  room:
    address: rooms/{roomId}
    parameters:
      roomId: { description: The room identifier. }
    messages:
      chatSent:  { $ref: '#/components/messages/ChatSent' }
      presence:  { $ref: '#/components/messages/Presence' }
operations:
  sendChat:    { action: receive, channel: { $ref: '#/channels/room' }, messages: [ { $ref: '#/channels/room/messages/chatSent' } ] }
  onPresence:  { action: send,    channel: { $ref: '#/channels/room' }, messages: [ { $ref: '#/channels/room/messages/presence' } ] }
```

Generated `client.ts` (excerpt):

```ts
export class RoomChannel {
  private constructor(private readonly transport: Transport) {}

  static connect(baseUrl: string, params: { roomId: string }): RoomChannel {
    return new RoomChannel(new WebSocketTransport(`${baseUrl}/rooms/${params.roomId}`));
  }

  /** Publish a `ChatSent` message. */
  sendChatSent(msg: ChatSent): void { this.transport.send(JSON.stringify(msg)); }

  /** Subscribe to `Presence` messages. Returns an unsubscribe function. */
  onPresence(handler: (msg: Presence) => void): () => void {
    return this.transport.subscribe((data) => handler(JSON.parse(data) as Presence));
  }

  close(): void { this.transport.close(); }
}
```

Generated `handlers.gleam` (excerpt):

```gleam
/// Handle `sendChat` arriving on `rooms/{roomId}`.
pub fn handle_send_chat(msg: types.ChatSent) -> Nil { todo }

/// Emit `onPresence` on `rooms/{roomId}`.
pub fn emit_on_presence(msg: types.Presence) -> Nil { todo }
```

Full generated output for the chat spec lives in [`examples/generated/`](examples/generated).

## Using it in React

The store layer fits `useSyncExternalStore`, so components need no `useEffect`.
Make the store a module singleton and read it:

```tsx
import { useSyncExternalStore } from "react";
import { createPresenceStore } from "./generated/stores";

const presence = createPresenceStore("wss://chat.example.com", { roomId: "42" });

export function usePresence() {
  return useSyncExternalStore(presence.subscribe, presence.getSnapshot);
}
```

The stores import nothing from React — they work equally with Vue, Svelte, Solid,
or vanilla JS.

## Configuration

The CLI auto-detects `asyncapi.config.yaml`, or takes `--config=path`. The point
of the config is that the two targets rarely share a directory — the TypeScript
client belongs in a frontend project, the Gleam handlers in a backend one.

```yaml
spec: ./asyncapi.yaml

output:
  gleam:
    enabled: true
    dir: ./backend/src/generated
    types_module: generated/types   # how handlers.gleam imports the types module

  typescript:
    enabled: true
    dir: ./frontend/src/api
    stores: true
    stores_dir: ./frontend/src/api  # defaults to `dir`
    client_module: ./client         # how stores.ts imports the client
```

Set `enabled: false` on a target to skip it. With no config, positional args
still work: `generate <spec> [out-dir] [--stores]`.

See [`asyncapi.config.example.yaml`](asyncapi.config.example.yaml) for the
annotated reference.

## Library API

```gleam
import nori_asyncapi

pub fn main() {
  let assert Ok(doc) = nori_asyncapi.parse_file("asyncapi.yaml")
  let spec = nori_asyncapi.build_ir(doc)

  let client = nori_asyncapi.generate_typescript(spec)
  let stores = nori_asyncapi.generate_typescript_stores(spec, "./client")
  let types = nori_asyncapi.generate_gleam_types(spec)
  let handlers = nori_asyncapi.generate_gleam_handlers(spec, "generated/types")
}
```

| function | returns |
|----------|---------|
| `parse_yaml` / `parse_json` / `parse_file` | typed `Document` |
| `build_ir(doc)` | `AsyncCodegenIR` |
| `generate_typescript(spec)` | neutral TS client |
| `generate_typescript_stores(spec, client_module)` | neutral TS store layer |
| `generate_gleam_types(spec)` | Gleam types + codecs |
| `generate_gleam_handlers(spec, types_module)` | Gleam handler stubs |

## Architecture

```
YAML/JSON spec
    ↓ nori_asyncapi/yaml.gleam (taffy → JSON → decoder)
Document (typed AsyncAPI model)
    ↓ nori_asyncapi/ir_builder.gleam (payloads delegate to nori.parse_schema)
AsyncCodegenIR (channels/operations/messages; types reuse nori's TypeDef)
    ↓ codegen/typescript.gleam · codegen/gleam_types.gleam · codegen/gleam_handlers.gleam
Generated code
```

## Scope

Supported: info, servers, channels, operations, messages (inline + `$ref`),
components (messages/schemas/channels/parameters), channel address parameters,
WebSocket + SSE transports.

Not yet: operation/message traits, correlationId, bindings, Kafka/NATS/AMQP/MQTT
transport codegen, multi-file `$ref` bundling, runtime payload validation.

## License

Apache-2.0.
