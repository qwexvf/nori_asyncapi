import gleam/option.{None, Some}
import gleeunit/should
import nori_asyncapi/config
import simplifile

fn load(yaml: String) -> config.Config {
  // config.load reads a file, so round-trip through a temp file.
  let path = "build/test_config.yaml"
  let assert Ok(_) = simplifile.write(path, yaml)
  let assert Ok(cfg) = config.load(path)
  cfg
}

pub fn full_config_splits_targets_test() {
  let cfg =
    load(
      "spec: ./api.yaml
output:
  gleam:
    enabled: true
    dir: ./backend/src/generated
    types_module: shared/types
  typescript:
    enabled: true
    dir: ./frontend/src/api
    stores: true
    client_module: ./client
",
    )

  cfg.spec |> should.equal("./api.yaml")

  let assert Some(g) = cfg.gleam
  g.dir |> should.equal("./backend/src/generated")
  g.types_module |> should.equal("shared/types")

  let assert Some(t) = cfg.typescript
  t.dir |> should.equal("./frontend/src/api")
  t.stores |> should.be_true
  // stores_dir defaults to dir when omitted
  t.stores_dir |> should.equal("./frontend/src/api")
  t.client_module |> should.equal("./client")
}

pub fn disabled_target_is_none_test() {
  let cfg =
    load(
      "spec: ./api.yaml
output:
  gleam:
    enabled: false
  typescript:
    dir: ./out
",
    )
  cfg.gleam |> should.equal(None)
  let assert Some(t) = cfg.typescript
  t.dir |> should.equal("./out")
  // stores defaults off
  t.stores |> should.be_false
}

pub fn minimal_config_defaults_test() {
  let cfg = load("spec: ./api.yaml\n")
  cfg.spec |> should.equal("./api.yaml")
  // no output block → both targets absent
  cfg.gleam |> should.equal(None)
  cfg.typescript |> should.equal(None)
}

pub fn default_config_from_args_test() {
  let cfg = config.default("./api.yaml", "./gen", True)
  let assert Some(g) = cfg.gleam
  g.dir |> should.equal("./gen")
  let assert Some(t) = cfg.typescript
  t.dir |> should.equal("./gen")
  t.stores |> should.be_true
}
