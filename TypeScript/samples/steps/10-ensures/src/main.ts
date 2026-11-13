import { checkModel } from "leanfran/verify"
import { distance } from "./dist.ts"

console.log(distance(3, 10), distance(10, 3), distance(-4, 4))
await checkModel(distance, { seed: 1 })
console.log("checkModel: distance satisfies nonneg and symmetric")
