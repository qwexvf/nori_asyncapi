//// Gleam payload-type generator.
////
//// Reuses nori's own Gleam type emitter: the AsyncAPI IR's `types` (nori
//// `TypeDef`s) are wrapped in a synthetic `CodegenIR` and handed to
//// `nori/codegen/gleam_types`. Message payloads come out as the same records /
//// enums / decoders nori produces for REST bodies.

import gleam/option
import nori/codegen/gleam_types as nori_gleam_types
import nori/codegen/ir as nori_ir
import nori_asyncapi/ir.{type AsyncCodegenIR}

/// Generate a complete Gleam types module (types + JSON encoders/decoders).
pub fn generate(spec: AsyncCodegenIR) -> String {
  nori_gleam_types.generate(to_nori_ir(spec))
}

fn to_nori_ir(spec: AsyncCodegenIR) -> nori_ir.CodegenIR {
  nori_ir.CodegenIR(
    title: spec.title,
    version: spec.version,
    base_url: option.None,
    types: spec.types,
    endpoints: [],
    security_schemes: [],
    global_security: [],
  )
}
