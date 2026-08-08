//// Minimal CLI. Generates from an `asyncapi.config.yaml` when present (or
//// `--config=path`), otherwise from positional args into one directory.
////
//// ```sh
//// gleam run -m nori_asyncapi/cli -- generate                         # auto-detect config
//// gleam run -m nori_asyncapi/cli -- generate --config=my.config.yaml
//// gleam run -m nori_asyncapi/cli -- generate spec.yaml ./out --stores # no config
//// ```

import argv
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import nori_asyncapi
import nori_asyncapi/config.{type Config}
import nori_asyncapi/yaml
import simplifile

const default_config_path = "asyncapi.config.yaml"

pub fn main() {
  case argv.load().arguments {
    ["generate", ..rest] -> run(rest)
    _ -> usage()
  }
}

fn usage() -> Nil {
  io.println(
    "usage:\n"
    <> "  generate                          # uses ./asyncapi.config.yaml\n"
    <> "  generate --config=<path>          # explicit config\n"
    <> "  generate <spec> [out-dir] [--stores]   # no config",
  )
}

fn run(args: List(String)) -> Nil {
  case resolve_config(args) {
    Error(msg) -> io.println("error: " <> msg)
    Ok(cfg) -> generate(cfg)
  }
}

/// Decide where the config comes from: explicit `--config`, a positional spec
/// (default config), or the auto-detected file.
fn resolve_config(args: List(String)) -> Result(Config, String) {
  let flag = list.find_map(args, fn(a) { flag_value(a, "--config=") })
  let stores = list.contains(args, "--stores")
  let positionals = list.filter(args, fn(a) { !string.starts_with(a, "--") })

  case flag, positionals {
    Ok(path), _ -> load_config(path)
    Error(_), [spec, out_dir, ..] -> Ok(config.default(spec, out_dir, stores))
    Error(_), [spec] -> Ok(config.default(spec, "./generated", stores))
    Error(_), [] ->
      case simplifile.is_file(default_config_path) {
        Ok(True) -> load_config(default_config_path)
        _ -> Error("no spec given and no " <> default_config_path <> " found")
      }
  }
}

fn load_config(path: String) -> Result(Config, String) {
  case config.load(path) {
    Ok(cfg) -> Ok(cfg)
    Error(config.ReadError(p)) -> Error("cannot read config: " <> p)
    Error(config.ParseError(m)) -> Error("config parse: " <> m)
    Error(config.DecodeErrors(errs)) ->
      Error("config invalid: " <> string.inspect(errs))
  }
}

fn flag_value(arg: String, prefix: String) -> Result(String, Nil) {
  case string.starts_with(arg, prefix) {
    True -> Ok(string.drop_start(arg, string.length(prefix)))
    False -> Error(Nil)
  }
}

fn generate(cfg: Config) -> Nil {
  case nori_asyncapi.parse_file(cfg.spec) {
    Error(err) -> io.println("error: " <> describe_error(err))
    Ok(doc) -> {
      let spec = nori_asyncapi.build_ir(doc)
      write_gleam(cfg, spec)
      write_typescript(cfg, spec)
    }
  }
}

fn write_gleam(cfg: Config, spec) -> Nil {
  case cfg.gleam {
    None -> Nil
    Some(t) -> {
      let _ = simplifile.create_directory_all(t.dir)
      write(t.dir <> "/types.gleam", nori_asyncapi.generate_gleam_types(spec))
      write(
        t.dir <> "/handlers.gleam",
        nori_asyncapi.generate_gleam_handlers(spec, t.types_module),
      )
      write(
        t.dir <> "/server.gleam",
        nori_asyncapi.generate_gleam_server(spec, t.types_module),
      )
    }
  }
}

fn write_typescript(cfg: Config, spec) -> Nil {
  case cfg.typescript {
    None -> Nil
    Some(t) -> {
      let _ = simplifile.create_directory_all(t.dir)
      case t.transport {
        "gateway" ->
          // one multiplexing client; channel-style stores don't apply
          write(
            t.dir <> "/client.ts",
            nori_asyncapi.generate_typescript_gateway(spec),
          )
        _ -> {
          write(t.dir <> "/client.ts", nori_asyncapi.generate_typescript(spec))
          case t.stores {
            False -> Nil
            True -> {
              let _ = simplifile.create_directory_all(t.stores_dir)
              write(
                t.stores_dir <> "/stores.ts",
                nori_asyncapi.generate_typescript_stores(spec, t.client_module),
              )
            }
          }
        }
      }
    }
  }
}

fn write(path: String, content: String) -> Nil {
  case simplifile.write(path, content) {
    Ok(_) -> io.println("  " <> path)
    Error(_) -> io.println("  failed: " <> path)
  }
}

fn describe_error(err: yaml.LoadError) -> String {
  case err {
    yaml.SyntaxError(msg) -> msg
    yaml.FileError(path, msg) -> path <> ": " <> msg
    yaml.DecodeErrors(errors) ->
      "decode failed (" <> string.inspect(errors) <> ")"
  }
}
