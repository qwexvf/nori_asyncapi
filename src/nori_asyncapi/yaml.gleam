//// YAML / JSON loading for AsyncAPI specs.
////
//// Same bridge nori uses: taffy parses YAML to a `YamlValue`, round-trips it
//// to JSON, then the AsyncAPI decoder runs over the `Dynamic`.

import gleam/dynamic/decode.{type DecodeError}
import gleam/json
import gleam/string
import nori_asyncapi/decoder
import nori_asyncapi/document.{type Document}
import simplifile
import taffy

pub type LoadError {
  SyntaxError(message: String)
  DecodeErrors(errors: List(DecodeError))
  FileError(path: String, message: String)
}

/// Parse an AsyncAPI document from a YAML string.
pub fn parse_yaml(input: String) -> Result(Document, LoadError) {
  case taffy.parse(input) {
    Error(err) -> Error(SyntaxError(err.message))
    Ok(value) -> decode_json_string(taffy.to_json_string(value))
  }
}

/// Parse an AsyncAPI document from a JSON string.
pub fn parse_json(input: String) -> Result(Document, LoadError) {
  decode_json_string(input)
}

/// Load and parse a spec file (`.yaml`/`.yml` → YAML, `.json` → JSON, else
/// YAML first since it is a JSON superset).
pub fn parse_file(path: String) -> Result(Document, LoadError) {
  case simplifile.read(path) {
    Error(_) -> Error(FileError(path, "Could not read file"))
    Ok(content) ->
      case is_json_file(path) {
        True -> parse_json(content)
        False -> parse_yaml(content)
      }
  }
}

fn decode_json_string(json_str: String) -> Result(Document, LoadError) {
  case json.parse(json_str, decode.dynamic) {
    Error(_) -> Error(SyntaxError("Invalid JSON produced from spec"))
    Ok(dyn) ->
      case decoder.decode_document(dyn) {
        Ok(doc) -> Ok(doc)
        Error(errors) -> Error(DecodeErrors(errors))
      }
  }
}

fn is_json_file(path: String) -> Bool {
  string.ends_with(path, ".json")
}
