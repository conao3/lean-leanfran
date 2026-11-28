import { spawnSync } from "node:child_process"
import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs"
import { delimiter, dirname, join, relative, resolve } from "node:path"
import { beforeAll, describe, expect, test } from "vite-plus/test"
import { GENERATOR_VERSION, LEAN_VERSION } from "../src/embed.ts"

const ROOT = resolve(import.meta.dirname, "..")
const LEANFRAN_CLI = join(ROOT, "../../.lake/build/bin/leanfran")
const FIXTURE = join(ROOT, "test/embed/app")
const OUT = join(ROOT, "test-out/embed")
const NODE_ONLY = join(OUT, "node-only-bin")
const TIMEOUT = 300_000

interface Run {
  readonly status: number
  readonly stdout: string
  readonly stderr: string
}

function run(cmd: string, args: readonly string[], cwd: string, env: NodeJS.ProcessEnv = {}): Run {
  const r = spawnSync(cmd, args, {
    cwd,
    encoding: "utf8",
    env: { ...process.env, LEANFRAN_CLI: undefined, LEANFRAN_TS_AUTO_SYNC: "0", ...env },
  })
  if (r.error !== undefined) throw r.error
  return { status: r.status ?? -1, stdout: r.stdout, stderr: r.stderr }
}

function leanTs(args: readonly string[], cwd: string = ROOT, env: NodeJS.ProcessEnv = {}): Run {
  return run(LEANFRAN_CLI, ["--lang", "typescript", ...args], cwd, env)
}

function copyProject(from: string, name: string): string {
  const dir = join(OUT, name)
  rmSync(dir, { recursive: true, force: true })
  cpSync(from, dir, {
    recursive: true,
    filter: (src) =>
      !src.includes("/.leanfran/typescript") &&
      !src.endsWith("/.leanfran/lock") &&
      !src.includes("/node_modules"),
  })
  mkdirSync(join(dir, "node_modules"), { recursive: true })
  symlinkSync(relative(join(dir, "node_modules"), ROOT), join(dir, "node_modules/leanfran"))
  symlinkSync(
    relative(join(dir, "node_modules"), join(ROOT, "node_modules/zod")),
    join(dir, "node_modules/zod"),
  )
  return dir
}

function sync(dir: string): Run {
  return leanTs(["sync", "--package", dir])
}

function nodeEval(dir: string, code: string, env: NodeJS.ProcessEnv = {}): Run {
  return run(process.execPath, ["--input-type=module", "-e", code], dir, env)
}

function edit(file: string, from: string, to: string): void {
  const text = readFileSync(file, "utf8")
  if (!text.includes(from)) throw new Error(`${file} does not contain ${from}`)
  writeFileSync(file, text.replace(from, to))
}

function generatedFiles(dir: string): Map<string, string> {
  const out = new Map<string, string>()
  const walk = (d: string): void => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name)
      if (e.isDirectory()) walk(p)
      else if (p.includes("/_lean/")) out.set(relative(dir, p), readFileSync(p, "utf8"))
    }
  }
  walk(join(dir, "src"))
  out.set("leanfran.manifest.json", readFileSync(join(dir, "leanfran.manifest.json"), "utf8"))
  return out
}

const SCHEMAS = `function schema(min: number) {
  const json = {
    type: "object",
    properties: { sku: { type: "string" }, qty: { type: "integer", minimum: min } },
    required: ["sku", "qty"],
    additionalProperties: false,
  }
  return {
    "~standard": {
      version: 1 as const,
      vendor: "test",
      validate: (value: unknown) => ({ value }),
      jsonSchema: { input: () => json, output: () => json },
    },
  }
}

export const LineItem = schema(1)
`

const PRICED = `import { lean } from "leanfran"
import * as priced from "./_lean/priced.ts"
import { LineItem } from "./schemas.ts"

export const pricedBlock = lean(
  "priced",
  String.raw\`
def total (prices : List Nat) : Nat := prices.foldl (· + ·) 0
\`,
  { models: { LineItem }, output: { tagKey: "kind" } },
)

export const total: typeof priced.total = priced.total
`

let app = ""
let appSync: Run = { status: -1, stdout: "", stderr: "" }

beforeAll(() => {
  if (!existsSync(LEANFRAN_CLI))
    throw new Error(`${LEANFRAN_CLI} is missing; run lake --dir ../.. build leanfran`)
  if (!existsSync(join(ROOT, "dist/index.js")))
    throw new Error("dist/index.js is missing; run vp pack")
  mkdirSync(OUT, { recursive: true })
  rmSync(NODE_ONLY, { recursive: true, force: true })
  mkdirSync(NODE_ONLY)
  symlinkSync(process.execPath, join(NODE_ONLY, "node"))
  for (const cmd of ["sha256sum", "shasum"]) {
    const found = spawnSync("sh", ["-c", `command -v ${cmd}`], { encoding: "utf8" }).stdout.trim()
    if (found !== "") symlinkSync(found, join(NODE_ONLY, cmd))
  }
  app = copyProject(FIXTURE, "app")
  appSync = leanTs(["sync", "--package", app], ROOT, { LEANFRAN_CLI: "unused" })
}, TIMEOUT)

describe("leanfran --lang typescript sync", () => {
  test("checks the proofs and generates modules whose functions run", () => {
    expect(appSync.stderr).toContain("6 blocks checked and generated")
    expect(appSync.status).toBe(0)
    const r = run(process.execPath, ["--test", "--test-reporter=tap", "test/"], app)
    expect(r.stdout).toContain("# pass 5")
    expect(r.status).toBe(0)
  })

  test("the committed fixture is what sync generates", () => {
    expect(generatedFiles(app)).toEqual(generatedFiles(FIXTURE))
  })

  test("a block shares the types of the block it uses", () => {
    expect(
      readFileSync(
        join(app, ".leanfran/typescript/workspace/LeanTsEmbed/report/report.lean"),
        "utf8",
      ),
    ).toContain(
      "import LeanTsEmbed.«geometry».«geometry»\n\nnamespace LeanTsEmbed.«report».«report»\nopen LeanTsEmbed.«geometry».«geometry»\n",
    )
    expect(appSync.stderr).not.toContain("skipped LeanTsEmbed.report.report.boxArea")
    const report = readFileSync(join(app, "src/_lean/report__report.ts"), "utf8")
    expect(report).toContain('import * as $x0 from "./geometry__geometry.ts"')
    expect(report).toContain("export function boxArea(b: $x0.Box): bigint")
  })

  test("a model becomes a Lean structure whose constraints are proof fields", () => {
    const models = readFileSync(
      join(app, ".leanfran/typescript/workspace/LeanTsModels/pricing.lean"),
      "utf8",
    )
    expect(models).toContain(
      "structure LineItem where\n  kind : LeanTsEnums.«pricing».LineItem_kind\n  note? : Option String\n  qty : Nat\n  qty_ge : 1 ≤ qty\n",
    )
    expect(models).toContain(
      '/-- The model LineItem of src/pricing.ts. Not assumed in Lean: sku pattern "^[A-Z0-9-]+$". -/',
    )
    expect(models).toContain("structure Order where\n  buyer : String\n  item : LineItem\n")
    expect(
      readFileSync(
        join(app, ".leanfran/typescript/workspace/LeanTsEmbed/pricing/pricing.lean"),
        "utf8",
      ),
    ).toContain(
      "import LeanTsModels.«pricing»\n\nnamespace LeanTsEmbed.«pricing».«pricing»\nopen LeanTsModels.«pricing»\n",
    )
    const pricing = readFileSync(join(app, "src/_lean/pricing__pricing.ts"), "utf8")
    expect(pricing).toContain('import type { LineItem as $m0 } from "../pricing.ts"')
    expect(pricing).toContain(
      "export function total(items: readonly L.InferOutput<typeof $m0>[], d: Discount): bigint",
    )
  })

  test(
    "a model whose JSON Schema has no Lean form stops with 254",
    () => {
      const dir = copyProject(FIXTURE, "bad-model")
      edit(
        join(dir, "src/pricing.ts"),
        "note: z.string().optional(),",
        "note: z.union([z.string(), z.number()]),",
      )
      const r = sync(dir)
      expect(r.status).toBe(254)
      expect(r.stderr).toContain("src/pricing.ts: the model LineItem.note: the schema")
      const named = copyProject(FIXTURE, "inline-model")
      edit(
        join(named, "src/pricing.ts"),
        "{ models: { LineItem, Order },",
        "{ models: { LineItem: z.object({}) },",
      )
      const inline = sync(named)
      expect(inline.status).toBe(254)
      expect(inline.stderr).toContain(
        "the model LineItem must be an exported variable of the module",
      )
    },
    TIMEOUT,
  )

  test(
    "a wrong proof stops with 254 and the position in the TypeScript file",
    () => {
      const dir = copyProject(FIXTURE, "wrong-proof")
      const file = join(dir, "src/arith.ts")
      edit(file, "unfold double; omega", "unfold double; rfl")
      const r = sync(dir)
      expect(r.status).toBe(254)
      expect(r.stderr).toContain(
        `${relative(ROOT, file)}:10:18: error: (lean block src/arith.ts:arith, Lean 5:17) Tactic \`rfl\` failed`,
      )
    },
    TIMEOUT,
  )

  test("a block with an unknown use stops with 254", () => {
    const dir = copyProject(FIXTURE, "unknown-use")
    edit(join(dir, "src/report.ts"), "./geometry.ts:geometry", "./geometry.ts:shapes")
    const r = sync(dir)
    expect(r.status).toBe(254)
    expect(r.stderr).toContain('uses "./geometry.ts:shapes", which is not a block of the package')
  })

  test("a source that is not a literal stops with 254", () => {
    const dir = copyProject(FIXTURE, "dynamic-source")
    edit(
      join(dir, "src/arith.ts"),
      'lean(\n  "arith",\n  String.raw`',
      'lean(\n  "arith",\n  String.raw`${"x"}',
    )
    const r = sync(dir)
    expect(r.status).toBe(254)
    expect(r.stderr).toContain(
      `${join(dir, "src/arith.ts")}:6:3: the Lean source of lean(...) must be a template literal`,
    )
  })

  test("an invalid output setting stops with 254", () => {
    const dir = copyProject(FIXTURE, "bad-setting")
    edit(
      join(dir, "src/arith.ts"),
      "`,\n)",
      '`,\n  { output: { tagKey: "not-an-identifier" } },\n)',
    )
    const r = sync(dir)
    expect(r.status).toBe(254)
    expect(r.stderr).toContain("tagKey must be a JavaScript identifier")
  })
})

describe("stale blocks", () => {
  test(
    "lean() throws LeanBlockStale and status lists the block without Lake",
    () => {
      const dir = copyProject(app, "stale")
      edit(join(dir, "src/arith.ts"), "xs.foldl (· + ·) 0", "xs.foldl (· + ·) 1")
      const r = nodeEval(dir, 'await import("./src/arith.ts")')
      expect(r.status).not.toBe(0)
      expect(r.stderr).toContain('LeanBlockStale: the Lean block "arith" is stale')
      const s = leanTs(["status", "--package", dir], ROOT, { PATH: NODE_ONLY })
      expect(s.stdout).toBe("src/arith.ts:arith: stale\n")
      expect(s.status).toBe(1)
      expect(leanTs(["status", "--package", app], ROOT, { PATH: NODE_ONLY }).status).toBe(0)
    },
    TIMEOUT,
  )

  test(
    "LEANFRAN_TS_AUTO_SYNC=1 runs sync and the next start uses the new module",
    () => {
      const dir = copyProject(app, "auto-sync")
      edit(join(dir, "src/arith.ts"), "xs.foldl (· + ·) 0", "xs.foldl (· + ·) 100")
      const code =
        'const a = await import("./src/_lean/arith.ts"); await import("./src/arith.ts"); console.log(String(a.sum([1n])))'
      const first = nodeEval(dir, code, {
        PATH: [dirname(LEANFRAN_CLI), process.env["PATH"]].join(delimiter),
        LEANFRAN_TS_AUTO_SYNC: "1",
      })
      expect(first.stderr).toContain('leanfran: regenerated the Lean block "arith"')
      expect(first.stdout).toBe("1\n")
      expect(first.status).toBe(0)
      const second = nodeEval(dir, code)
      expect(second.stdout).toBe("101\n")
      expect(second.status).toBe(0)
    },
    TIMEOUT,
  )

  test(
    "the JSON Schema of the models and the output settings are in the key",
    () => {
      const dir = copyProject(app, "models")
      writeFileSync(join(dir, "src/schemas.ts"), SCHEMAS)
      writeFileSync(join(dir, "src/priced.ts"), PRICED)
      const r = sync(dir)
      expect(r.stderr).toContain("7 blocks checked and generated")
      expect(r.status).toBe(0)
      const ok = nodeEval(
        dir,
        'const m = await import("./src/priced.ts"); console.log(String(m.total([2n, 3n])), String(m.pricedBlock.models.LineItem !== undefined))',
      )
      expect(ok.stdout).toBe("5 true\n")
      expect(ok.status).toBe(0)
      edit(join(dir, "src/schemas.ts"), "schema(1)", "schema(2)")
      expect(leanTs(["status", "--package", dir]).stdout).toContain("src/priced.ts:priced: stale")
      const stale = nodeEval(dir, 'await import("./src/priced.ts")')
      expect(stale.stderr).toContain('LeanBlockStale: the Lean block "priced" is stale')
      edit(join(dir, "src/schemas.ts"), "schema(2)", "schema(1)")
      edit(join(dir, "src/priced.ts"), 'tagKey: "kind"', 'tagKey: "type"')
      expect(leanTs(["status", "--package", dir]).stdout).toContain("src/priced.ts:priced: stale")
      edit(join(dir, "src/priced.ts"), 'tagKey: "type"', 'tagKey: "kind"')
      const pkg = join(dir, "package.json")
      expect(leanTs(["status", "--package", dir]).status).toBe(0)
      writeFileSync(
        pkg,
        JSON.stringify({
          ...JSON.parse(readFileSync(pkg, "utf8")),
          leanfran: { option: "undefined" },
        }),
      )
      expect(leanTs(["status", "--package", dir]).stdout).toContain("src/arith.ts:arith: stale")
      const pkgStale = nodeEval(dir, 'await import("./src/arith.ts")')
      expect(pkgStale.stderr).toContain(
        'LeanBlockStale: the Lean block "arith" is stale (the leanfran settings of its package.json changed since `leanfran --lang typescript sync` generated it)',
      )
      expect(sync(dir).status).toBe(0)
      expect(nodeEval(dir, 'await import("./src/arith.ts")').status).toBe(0)
    },
    TIMEOUT,
  )
})

describe("without Lean", () => {
  test("the committed fixture runs with node --test when lake and leanfran are not on PATH", () => {
    const env = { PATH: NODE_ONLY }
    for (const cmd of ["lake", "leanfran", "lean"]) {
      const r = spawnSync(cmd, ["--version"], { env })
      expect(r.error?.message).toContain("ENOENT")
    }
    const dir = copyProject(FIXTURE, "no-lean")
    const r = run("node", ["--test", "--test-reporter=tap", "test/"], dir, env)
    expect(r.stdout).toContain("# pass 5")
    expect(r.status).toBe(0)
  })
})

describe("leanfran --lang typescript generate", () => {
  test(
    "emits a TypeScript module per module of a lake project",
    () => {
      const dir = copyProject(join(ROOT, "test/project"), "project")
      const r = leanTs(["generate", "--lake-dir", ".", "--output-dir", "ts"], dir)
      expect(r.status).toBe(0)
      expect(readdirSync(join(dir, "ts/Tally")).toSorted()).toEqual(["Basic.ts", "Format.ts"])
      const out = nodeEval(
        dir,
        'const f = await import("./ts/Tally/Format.ts"); const b = await import("./ts/Tally/Basic.ts"); console.log(f.Tally.report([1n, 2n]), String(b.Tally.total([4n, 5n])))',
      )
      expect(out.stdout).toBe("2 items, total 3 9\n")
      expect(out.status).toBe(0)
    },
    TIMEOUT,
  )
})

describe("versions", () => {
  test("GENERATOR_VERSION is the generatorVersion of LeanTs/Cli.lean and of leanfran --lang typescript", () => {
    const m = /^def generatorVersion : String := "([^"]*)"$/mu.exec(
      readFileSync(join(ROOT, "LeanTs/Cli.lean"), "utf8"),
    )
    expect(m?.[1]).toBe(GENERATOR_VERSION)
    expect(run(LEANFRAN_CLI, ["--lang", "typescript", "--generator-version"], ROOT).stdout).toBe(
      `${GENERATOR_VERSION}\n`,
    )
  })

  test("LEAN_VERSION is the Lean version of lean-toolchain", () => {
    expect(readFileSync(join(ROOT, "../../lean-toolchain"), "utf8")).toBe(
      `leanprover/lean4:v${LEAN_VERSION}\n`,
    )
  })

  test.each([
    ["LEANFRAN_VERSION", "release version"],
    ["LEANFRAN_GENERATOR_VERSION", "generator version"],
    ["LEANFRAN_LEAN_VERSION", "Lean version"],
  ])("a compiler whose %s differs from the npm package exits with 255", (variable, name) => {
    const bin = join(OUT, `wrong-${variable}`)
    rmSync(bin, { recursive: true, force: true })
    mkdirSync(bin)
    writeFileSync(
      join(bin, "node"),
      `#!/bin/sh\n${variable}=0.0.0 exec ${JSON.stringify(process.execPath)} "$@"\n`,
      { mode: 0o755 },
    )
    const r = leanTs(["status", "--package", app], ROOT, {
      PATH: [bin, NODE_ONLY].join(delimiter),
    })
    expect(r.stderr).toContain(`compiler ${name} "0.0.0", expected `)
    expect(r.status).toBe(255)
  })

  test("leanfran --version is the package version", () => {
    const pkg: unknown = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8"))
    expect(leanTs(["--version"]).stdout).toBe(`${String(Reflect.get(Object(pkg), "version"))}\n`)
  })
})

describe("cli parameters", () => {
  test("sync without --package exits with 252", () => {
    const r = leanTs(["sync"])
    expect(r.status).toBe(252)
    expect(r.stderr).toContain("--package is required")
  })

  test("sync without the project's npm package exits with an installation hint", () => {
    const dir = join(OUT, "missing-package")
    mkdirSync(dir, { recursive: true })
    const r = leanTs(["sync", "--package", dir])
    expect(r.status).toBe(255)
    expect(r.stderr).toContain("npm install leanfran")
  })

  test("leanfran --lang typescript --batch with an invalid file exits with 252", () => {
    const f = join(OUT, "bad-batch.json")
    mkdirSync(dirname(f), { recursive: true })
    writeFileSync(f, '[{"module": "X"}]')
    const r = run(LEANFRAN_CLI, ["--lang", "typescript", "module", "generate", "--batch", f], ROOT)
    expect(r.status).toBe(252)
    expect(r.stderr).toContain("invalid --batch file")
  })
})
