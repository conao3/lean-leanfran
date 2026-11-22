import * as json from "../../langs/PHP/test-out/schema/Json.ts"
import * as publicTypes from "../../langs/PHP/test-out/schema/Public.ts"

const types = {
  Bigger: publicTypes.Bigger,
  Bounds: publicTypes.Bounds,
  Choices: publicTypes.Choices,
  Color: json.Color,
  Data: json.Data,
  Discount: publicTypes.Discount,
  Packed: publicTypes.Packed,
  Shape: json.Shape,
  Sized: publicTypes.Sized,
  Small: publicTypes.Subtype0,
  Tree: json.Tree,
}
const targets = ["draft-2020-12", "draft-07", "openapi-3.0"]

function sorted(value) {
  if (Array.isArray(value)) return value.map(sorted)
  if (value !== null && typeof value === "object")
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, sorted(value[key])]))
  return value
}

const rows = Object.entries(types).flatMap(([type, schema]) =>
  targets.map((target) => {
    const converter = schema["~standard"].jsonSchema
    const input = JSON.stringify(sorted(converter.input({ target })))
    const output = JSON.stringify(sorted(converter.output({ target })))
    if (input !== output) throw new Error(`Input and output schemas differ for ${type} (${target})`)
    return JSON.stringify({ type, target, schema: JSON.parse(input) })
  }),
)
process.stdout.write(`[\n  ${rows.join(",\n  ")}\n]\n`)
