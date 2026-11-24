import * as json from "./Json.ts"
import * as publicTypes from "./Public.ts"

const types = {
  Big: json.Big,
  Color: json.Color,
  Data: json.Data,
  Discount: publicTypes.Discount,
  Packed: publicTypes.Packed,
  Range: publicTypes.Range,
  Shape: json.Shape,
  Tree: json.Tree,
}
const targets = ["draft-2020-12", "draft-07", "openapi-3.0"]
const rows = Object.entries(types).flatMap(([type, schema]) =>
  targets.map((target) => ({
    type,
    target,
    schema: schema["~standard"].jsonSchema.output({ target }),
  })),
)
process.stdout.write(JSON.stringify(rows) + "\n")
