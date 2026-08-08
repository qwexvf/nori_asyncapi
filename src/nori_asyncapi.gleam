//// AsyncAPI 3.x code generation for Gleam.
////
//// A satellite of [nori](https://github.com/qwexvf/nori): parses AsyncAPI
//// specs, builds a codegen IR whose payload types reuse nori's type model, and
//// emits TypeScript clients and Gleam handler stubs.
////
//// ## Quick start
////
//// ```gleam
//// import nori_asyncapi
////
//// pub fn main() {
////   let assert Ok(doc) = nori_asyncapi.parse_file("asyncapi.yaml")
////   let spec = nori_asyncapi.build_ir(doc)
////   let ts = nori_asyncapi.generate_typescript(spec)
////   let gleam = nori_asyncapi.generate_gleam_handlers(spec)
//// }
//// ```

import nori_asyncapi/codegen/gleam_handlers
import nori_asyncapi/codegen/gleam_server
import nori_asyncapi/codegen/gleam_types
import nori_asyncapi/codegen/typescript
import nori_asyncapi/document.{type Document}
import nori_asyncapi/ir.{type AsyncCodegenIR}
import nori_asyncapi/ir_builder
import nori_asyncapi/yaml

/// Parse an AsyncAPI document from a YAML string.
pub fn parse_yaml(input: String) -> Result(Document, yaml.LoadError) {
  yaml.parse_yaml(input)
}

/// Parse an AsyncAPI document from a JSON string.
pub fn parse_json(input: String) -> Result(Document, yaml.LoadError) {
  yaml.parse_json(input)
}

/// Load and parse an AsyncAPI spec file (YAML or JSON, by extension).
pub fn parse_file(path: String) -> Result(Document, yaml.LoadError) {
  yaml.parse_file(path)
}

/// Build the codegen IR from a parsed document.
pub fn build_ir(doc: Document) -> AsyncCodegenIR {
  ir_builder.build(doc)
}

/// Generate the neutral TypeScript client (payload types + per-channel client).
/// No framework dependency.
pub fn generate_typescript(spec: AsyncCodegenIR) -> String {
  typescript.generate(spec)
}

/// Generate the neutral TypeScript store layer — one `useSyncExternalStore`-
/// compatible observable per subscribe message. `client_module` is the import
/// path of the client module (e.g. `"./client"`). Imports no UI framework.
pub fn generate_typescript_stores(
  spec: AsyncCodegenIR,
  client_module: String,
) -> String {
  typescript.generate_stores(spec, client_module)
}

/// Generate a Gleam payload-types module (records/enums + JSON codecs), reusing
/// nori's Gleam type emitter.
pub fn generate_gleam_types(spec: AsyncCodegenIR) -> String {
  gleam_types.generate(spec)
}

/// Generate a Gleam handler-stub module. `types_module` is the import path of
/// the companion module from `generate_gleam_types`.
pub fn generate_gleam_handlers(
  spec: AsyncCodegenIR,
  types_module: String,
) -> String {
  gleam_handlers.generate(spec, types_module)
}

/// Generate the Gleam server dispatcher — a transport-neutral runtime that
/// decodes incoming `{type, payload}` frames into typed handler calls and
/// encodes outgoing messages. `types_module` is the import path of the
/// companion module from `generate_gleam_types`.
pub fn generate_gleam_server(
  spec: AsyncCodegenIR,
  types_module: String,
) -> String {
  gleam_server.generate(spec, types_module)
}
