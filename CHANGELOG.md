# Changelog

## v0.4.1

### Changed

- Bumped the `nori` dependency to `>= 2.0.0 and < 3.0.0`. nori 2.0.0's breaking
  changes (fetch target removal, generated-client body argument) do not affect
  the schema seam this package uses; no change to generated output.

## v0.4.0

### Fixed

- Per-channel TypeScript client now reads the server's `{type,payload}` envelope
  instead of blind-casting the whole frame to the payload type, so subscribed
  fields are no longer `undefined` (#1). Each `on*` handler also guards on the
  message `type`, so a channel with more than one `send` message demultiplexes
  correctly instead of delivering every frame to every handler (#2).
- Per-channel client `send*` (publish) now wraps the payload in the same
  `{type,payload}` envelope, matching what the Gleam `dispatch` decodes — the
  publish-direction mirror of #1. Previously it sent the raw payload, so every
  client publish decoded to `BadEnvelope` on the server.
- Send-only specs no longer generate dead Gleam: `handlers.gleam` drops the
  `emit_*` `todo` stubs (they duplicated `send_*`) and emits only the imports it
  uses; `server.gleam` no longer imports `gleam/dynamic/decode` when there is no
  dispatcher (#3).
- Send-only specs no longer emit an empty `handlers.gleam` with a dangling
  `types` import: the CLI skips the file entirely when there are no handlers to
  stub (#6).

### Added

- SSE resume helpers in `server.gleam` for specs with `send` messages: an
  `SseResume` type, `sse_event(id, frame)` to stamp a resume cursor on each
  event, and `sse_backlog(resume, last_event_id)` to replay only what a
  reconnecting `EventSource` client missed via `Last-Event-ID` (#4).

## v0.3.0

### Added

- Gateway transport mode for the TypeScript client (`generate_typescript_gateway`,
  or `transport: gateway` in the config). Emits a single `GatewayClient` that
  multiplexes every channel over one WebSocket using the `{type,payload}`
  envelope — the exact wire format the generated Gleam server dispatcher speaks.
  Fixes the mismatch where the default per-channel client (one URL per channel,
  raw payloads) could not talk to a single-`/ws` gateway server. Direction
  inversion is unchanged: server `send` → client `on*`, server `receive` →
  client `send*`. Verified `tsc --strict`.

## v0.2.0

### Added

- Gleam server dispatcher generator (`generate_gleam_server`, `server.gleam`): a
  transport-neutral runtime that decodes a `{type, payload}` envelope into typed
  handler callbacks (a `Handlers` record, one field per client→server message)
  and provides `send_*` encoders for server→client messages. Not coupled to any
  server library — feed it string frames from Mist or anything. Verified to
  compile with the real compiler.
- The CLI now also writes `server.gleam` alongside `types.gleam` and
  `handlers.gleam` for the Gleam target.

## v0.1.0

Initial release.

### Added

- Parse AsyncAPI 3.x specs (YAML or JSON) into a typed `Document`: info,
  servers, channels, operations, messages (inline + `$ref`), and components
  (messages/schemas/channels/parameters).
- `AsyncCodegenIR` — a codegen IR whose message payloads reuse nori's `TypeDef`
  type model, so a payload and a REST response body generate the same type.
- TypeScript generator: payload interfaces, a `Transport` runtime (WebSocket +
  SSE), and one typed class per channel. Direction is inverted to the client's
  point of view — a server `send` becomes a client `on*` subscription, a server
  `receive` becomes a client `send*` publish. Channel address variables become a
  typed `connect` parameter. Verified under `tsc --strict`.
- TypeScript store layer (opt-in): one `useSyncExternalStore`-compatible
  observable per subscribe message, importing no UI framework.
- Gleam generators: `types.gleam` (records/enums + JSON codecs via nori's
  emitter) and `handlers.gleam` (`handle_*` stubs for client→server, `emit_*`
  helpers for server→client). Verified to compile with the real compiler.
- `asyncapi.config.yaml` support: per-target output directories so the
  TypeScript client and Gleam handlers can land in separate projects, plus
  `types_module` / `client_module` import paths and a stores toggle.
- CLI: `generate` from a config file, `--config=path`, or positional args.
