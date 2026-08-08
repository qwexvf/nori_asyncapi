# Changelog

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
