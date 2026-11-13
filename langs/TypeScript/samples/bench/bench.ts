// Time the generated TypeScript against the native C build of the same Lean code.
// usage: node samples/bench/bench.ts   (after `lake build leanfran-typescript oracle-bench LeanTsTest`)
import { execFileSync } from "node:child_process"
import { mkdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { z } from "zod"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
mkdirSync(join(root, "test-out"), { recursive: true })
execFileSync(
  join(root, ".lake/build/bin/leanfran-typescript"),
  [
    "module",
    "generate",
    "--module-name",
    "LeanTsTest.Bench",
    "--search-path",
    join(root, ".lake/build/lib/lean"),
    "--runtime-path",
    "../src/runtime/index.ts",
    "--output-file",
    join(root, "test-out/bench.ts"),
  ],
  { stdio: ["ignore", "ignore", "inherit"] },
)
const bench = await import(join(root, "test-out/bench.ts"))

function timed<T>(f: () => T): [T, number] {
  const t = performance.now()
  const r = f()
  return [r, (performance.now() - t) / 1000]
}

function native(name: string, n: number): [bigint, number] {
  const t = performance.now()
  const out = execFileSync(join(root, ".lake/build/bin/oracle-bench"), [name, String(n)], {
    encoding: "utf8",
  })
  return [BigInt(out.trim()), (performance.now() - t) / 1000]
}

const workloads: [string, number[]][] = [
  ["pushLoop", [10_000, 100_000, 1_000_000]],
  ["fib", [100_000]],
  ["naiveFib", [25]],
  ["buildString", [10_000, 100_000]],
  ["sortList", [100_000]],
]

console.log("| workload | n | TypeScript (s) | native C (s) |")
console.log("|---|---|---|---|")
for (const [name, ns] of workloads) {
  for (const n of ns) {
    const [r, t] = timed(() => bench[name](n))
    const [rn, tn] = native(name, n)
    if (r !== rn) throw new Error(`${name}(${n}): ${r} !== ${rn}`)
    console.log(`| ${name} | ${n} | ${t.toFixed(3)} | ${tn.toFixed(3)} |`)
  }
}

const items = Array.from({ length: 10_000 }, (_, i) => ({ sku: `s${i}`, qty: i % 5, price: i }))
const PlainItem = z.object({
  sku: z.string(),
  qty: z.number().int().min(0),
  price: z.number().int().min(0),
})
const [, tCall] = timed(() => bench.total(items))
const [, tValidate] = timed(() => z.array(PlainItem).parse(items))
console.log()
console.log(
  `boundary: total(10^4 Items) ${tCall.toFixed(4)} s; z.array(object).parse(10^4 objects) ${tValidate.toFixed(4)} s`,
)
