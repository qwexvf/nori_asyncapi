//// Configuration for code generation.
////
//// An `asyncapi.config.yaml` lets the two targets write to different places —
//// the TypeScript client to a frontend project, the Gleam handlers to a backend
//// one — which a single output directory cannot express. The CLI auto-detects
//// the file, or takes `--config=path`. With no config it falls back to a
//// default built from positional args.
////
//// ```yaml
//// spec: ./asyncapi.yaml
//// output:
////   gleam:
////     enabled: true
////     dir: ./backend/src/generated
////     types_module: generated/types
////   typescript:
////     enabled: true
////     dir: ./frontend/src/api
////     stores: true
////     client_module: ./client
//// ```

import gleam/dynamic/decode.{type DecodeError, type Decoder}
import gleam/json
import gleam/option.{type Option, None, Some}
import simplifile
import taffy

/// Resolved generation config.
pub type Config {
  Config(spec: String, gleam: Option(GleamTarget), typescript: Option(TsTarget))
}

/// Gleam target: types + handler stubs.
pub type GleamTarget {
  GleamTarget(dir: String, types_module: String)
}

/// TypeScript target: client, and optionally the store layer.
pub type TsTarget {
  TsTarget(
    dir: String,
    stores: Bool,
    stores_dir: String,
    client_module: String,
    /// "channel" (per-channel clients, default) or "gateway" (one /ws,
    /// {type,payload} envelope — matches the Gleam server dispatcher).
    transport: String,
  )
}

pub type ConfigError {
  ReadError(path: String)
  ParseError(message: String)
  DecodeErrors(errors: List(DecodeError))
}

/// Default config from positional CLI args: both targets enabled, everything in
/// one directory. Matches the pre-config CLI behaviour.
pub fn default(spec: String, out_dir: String, stores: Bool) -> Config {
  Config(
    spec: spec,
    gleam: Some(GleamTarget(dir: out_dir, types_module: "generated/types")),
    typescript: Some(TsTarget(
      dir: out_dir,
      stores: stores,
      stores_dir: out_dir,
      client_module: "./client",
      transport: "channel",
    )),
  )
}

/// Load and parse a config file.
pub fn load(path: String) -> Result(Config, ConfigError) {
  case simplifile.read(path) {
    Error(_) -> Error(ReadError(path))
    Ok(content) ->
      case taffy.parse(content) {
        Error(err) -> Error(ParseError(err.message))
        Ok(value) -> decode_json(taffy.to_json_string(value))
      }
  }
}

fn decode_json(json_str: String) -> Result(Config, ConfigError) {
  case json.parse(json_str, decode.dynamic) {
    Error(_) -> Error(ParseError("config YAML produced invalid JSON"))
    Ok(dyn) ->
      case decode.run(dyn, config_decoder()) {
        Ok(cfg) -> Ok(cfg)
        Error(errors) -> Error(DecodeErrors(errors))
      }
  }
}

fn config_decoder() -> Decoder(Config) {
  use spec <- decode.field("spec", decode.string)
  use gleam <- decode.optional_field(
    "output",
    None,
    decode.at(["gleam"], gleam_target_decoder())
      |> decode.optional
      |> decode.map(option.flatten),
  )
  use typescript <- decode.optional_field(
    "output",
    None,
    decode.at(["typescript"], ts_target_decoder())
      |> decode.optional
      |> decode.map(option.flatten),
  )
  decode.success(Config(spec: spec, gleam: gleam, typescript: typescript))
}

fn gleam_target_decoder() -> Decoder(Option(GleamTarget)) {
  use enabled <- decode.optional_field("enabled", True, decode.bool)
  use dir <- decode.optional_field("dir", "./generated", decode.string)
  use types_module <- decode.optional_field(
    "types_module",
    "generated/types",
    decode.string,
  )
  case enabled {
    False -> decode.success(None)
    True ->
      decode.success(Some(GleamTarget(dir: dir, types_module: types_module)))
  }
}

fn ts_target_decoder() -> Decoder(Option(TsTarget)) {
  use enabled <- decode.optional_field("enabled", True, decode.bool)
  use dir <- decode.optional_field("dir", "./generated", decode.string)
  use stores <- decode.optional_field("stores", False, decode.bool)
  use stores_dir <- decode.optional_field("stores_dir", "", decode.string)
  use client_module <- decode.optional_field(
    "client_module",
    "./client",
    decode.string,
  )
  use transport <- decode.optional_field("transport", "channel", decode.string)
  // stores_dir defaults to dir when unset
  let resolved_stores_dir = case stores_dir {
    "" -> dir
    other -> other
  }
  case enabled {
    False -> decode.success(None)
    True ->
      decode.success(
        Some(TsTarget(
          dir: dir,
          stores: stores,
          stores_dir: resolved_stores_dir,
          client_module: client_module,
          transport: transport,
        )),
      )
  }
}
