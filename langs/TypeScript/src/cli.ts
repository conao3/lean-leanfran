#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync } from "node:fs"
import { registerHooks } from "node:module"
import { dirname, join, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { GENERATOR_VERSION, LEAN_VERSION } from "./embed.ts"
import { type Json } from "./key.ts"
import {
  aliasFile,
  type Block,
  blockLean,
  isRecord,
  leanName,
  modelsModule,
  named,
  outputsOf,
  type Package,
  packageModels,
  readPackage,
  resolveUse,
  specifier,
  type Summary,
} from "./project.ts"
import { posixRelative, ProjectError } from "./scan.ts"
import { scanFunctions, translatePackage } from "./verify/check.ts"

const USAGE = `usage: leanfran-typescript scan --root <root> --dir <dir>
       leanfran-typescript translate --root <root>
Run leanfran --lang typescript sync, check or status in the package; the compiler starts these commands.
`

function log(line: string): void {
  process.stderr.write(line.endsWith("\n") ? line : `${line}\n`)
}

function packageVersion(): string {
  const pkg: unknown = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"))
  const version = isRecord(pkg) ? pkg["version"] : undefined
  return typeof version === "string" ? version : ""
}

function checkVersions(): boolean {
  const release = packageVersion()
  const install = `install the compiler of this release with nix profile install 'github:conao3/lean-leanfran/v${release}#leanfran'`
  const checks = [
    [
      "release version",
      "LEANFRAN_VERSION",
      release,
      "use a compiler from the npm package's release or install the npm package of the compiler's release",
    ],
    [
      "generator version",
      "LEANFRAN_GENERATOR_VERSION",
      GENERATOR_VERSION,
      "rebuild the compiler from the npm package's source revision",
    ],
    [
      "Lean version",
      "LEANFRAN_LEAN_VERSION",
      LEAN_VERSION,
      "use a compiler built with the Lean version of the npm package's release",
    ],
  ] as const
  for (const [name, variable, want, fix] of checks) {
    const got = process.env[variable]
    if (got === undefined || got === "") {
      log(
        "leanfran-typescript: run leanfran --lang typescript sync, check or status in the package",
      )
      return false
    }
    if (got !== want) {
      log(
        `leanfran-typescript: compiler ${name} ${JSON.stringify(got)}, expected ${want}; ${fix}, or ${install}`,
      )
      return false
    }
  }
  return true
}

function placeholderHooks(root: string): void {
  const src = join(root, "src") + sep
  const missing = (url: string): boolean => {
    if (!url.startsWith("file:")) return false
    const path = fileURLToPath(url.split("?")[0] ?? url)
    return (
      path.startsWith(src) &&
      path.includes(`${sep}_lean${sep}`) &&
      path.endsWith(".ts") &&
      !existsSync(path)
    )
  }
  registerHooks({
    resolve(spec, context, nextResolve) {
      try {
        return nextResolve(spec, context)
      } catch (e) {
        if (context.parentURL !== undefined && (spec.startsWith(".") || spec.startsWith("/"))) {
          const url = new URL(spec, context.parentURL).href
          if (missing(url)) return { url, format: "module", shortCircuit: true }
        }
        throw e
      }
    },
    load(url, context, nextLoad) {
      if (missing(url)) return { format: "module", source: "export {}", shortCircuit: true }
      return nextLoad(url, context)
    },
  })
}

function blockName(b: Block): string {
  return `${b.module}:${b.name}`
}

function utf8Length(s: string): number {
  return Buffer.byteLength(s, "utf8")
}

type MapEntry = [number, number, number]

function escapeAt(raw: string, i: number): [string, number] {
  const c = raw[i + 1] ?? ""
  const simple: Readonly<Record<string, string>> = {
    b: "\b",
    f: "\f",
    n: "\n",
    r: "\r",
    t: "\t",
    v: "\v",
    "0": "\0",
  }
  if (c === "\n") return ["", 2]
  if (c === "x") return [String.fromCharCode(Number.parseInt(raw.slice(i + 2, i + 4), 16)), 4]
  if (c === "u") {
    if (raw[i + 2] === "{") {
      const close = raw.indexOf("}", i + 3)
      return [String.fromCodePoint(Number.parseInt(raw.slice(i + 3, close), 16)), close - i + 1]
    }
    return [String.fromCharCode(Number.parseInt(raw.slice(i + 2, i + 6), 16)), 6]
  }
  const value = simple[c]
  if (value !== undefined) return [value, 2]
  const cp = raw.codePointAt(i + 1) ?? 0
  const ch = String.fromCodePoint(cp)
  return [ch, 1 + ch.length]
}

function sourceMap(b: Block): MapEntry[] {
  const out: MapEntry[] = []
  const push = (e: MapEntry): void => {
    const last = out[out.length - 1]
    if (last !== undefined && last[0] === e[0]) out[out.length - 1] = e
    else out.push(e)
  }
  let line = b.sourceAt.line
  let col = b.sourceAt.col
  let offset = 0
  let cooked = ""
  push([0, line, col])
  const raw = b.rawSource
  let i = 0
  while (i < raw.length) {
    const ch = String.fromCodePoint(raw.codePointAt(i) ?? 0)
    if (ch === "\n") {
      cooked += ch
      offset += 1
      line++
      col = 1
      i++
      push([offset, line, col])
    } else if (ch === "\\" && !b.raw) {
      const [value, length] = escapeAt(raw, i)
      for (const r of raw.slice(i, i + length)) {
        if (r === "\n") {
          line++
          col = 1
        } else col += r.length
      }
      cooked += value
      offset += utf8Length(value)
      i += length
      push([offset, line, col])
    } else {
      cooked += ch
      offset += utf8Length(ch)
      col += ch.length
      i += ch.length
    }
  }
  if (cooked === b.source) return out
  const lines: MapEntry[] = [[0, b.sourceAt.line, b.sourceAt.col]]
  let at = 0
  b.source.split("\n").forEach((l, k) => {
    if (k === 0) {
      at = utf8Length(l)
      return
    }
    at += 1
    lines.push([at, b.sourceAt.line + k, 1])
    at += utf8Length(l)
  })
  return lines
}

function generatedFiles(dir: string, out: string[]): void {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name)
    if (e.isDirectory()) generatedFiles(p, out)
    else out.push(p)
  }
}

function strayFiles(pkg: Package, expected: ReadonlySet<string>): string[] {
  const out: string[] = []
  const walk = (dir: string): void => {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      if (!e.isDirectory() || e.name === "node_modules") continue
      const p = join(dir, e.name)
      if (e.name !== "_lean") {
        walk(p)
        continue
      }
      const files: string[] = []
      generatedFiles(p, files)
      for (const f of files) if (!expected.has(f)) out.push(posixRelative(pkg.root, f))
    }
  }
  walk(join(pkg.root, "src"))
  if (existsSync(join(pkg.root, ".leanfran", "blocks.json"))) out.push(".leanfran/blocks.json")
  return out.toSorted()
}

function jobOf(pkg: Package, b: Block): Json {
  return {
    module: b.leanModule.join("."),
    namespace: b.leanModule.join("."),
    type_modules: b.uses.map((u) => {
      const used = resolveUse(pkg, b, u)
      return { namespace: used.leanModule.join("."), module: specifier(b.outFile, used.outFile) }
    }),
    model_modules: b.models.map((m) => ({
      namespace: [...modelsModule(b), m.name].join("."),
      key: `${b.fnv}:${m.name}`,
      module: m.from.startsWith("/") ? specifier(b.outFile, m.from) : m.from,
      export: m.exportName,
    })),
    tag_key: b.settings["tagKey"] ?? "ctor",
    option: b.settings["option"] ?? "null",
    block: { name: b.name, module: b.module, fnv: b.fnv },
    ts_root: `${posixRelative(dirname(b.outFile), pkg.root)}/`,
  }
}

async function scan(root: string): Promise<unknown> {
  placeholderHooks(root)
  const pkg = await readPackage(root)
  const outputs = outputsOf(pkg.blocks)
  const blocks = pkg.blocks.map((b) => {
    const { prelude, postlude } = blockLean(pkg, b)
    return {
      name: blockName(b),
      module: b.leanModule.join("."),
      path: `${b.leanModule.join("/")}.lean`,
      prelude,
      text: b.source,
      postlude,
      map: sourceMap(b),
      origin: { file: b.module, line: b.at.line, column: b.at.col },
      uses: b.uses.map((u) => blockName(resolveUse(pkg, b, u))),
      hash: b.key,
      job: jobOf(pkg, b),
      output: { file: posixRelative(pkg.root, b.outFile) },
    }
  })
  const files: Json[] = []
  for (const b of pkg.blocks) {
    if (pkg.blocks.filter((x) => x.module === b.module).length !== 1) continue
    const alias = aliasFile(b)
    files.push({
      path: posixRelative(pkg.root, alias),
      text: outputs.get(alias) ?? "",
      block: blockName(b),
    })
  }
  const expected = new Set([
    ...outputs.keys(),
    ...pkg.blocks.map((b) => b.outFile.replace(/\.ts$/u, ".block.ts")),
  ])
  const models = packageModels(pkg)
  const workspace: Json[] = [...models].map(([parts, text]) => ({
    path: `${parts.join("/")}.lean`,
    text,
  }))
  workspace.push({
    path: "LeanTsModels.lean",
    text: [...models.keys()].map((m) => `import ${leanName(m)}\n`).join("") || "\n",
  })
  workspace.push({
    path: "LeanTsEmbed.lean",
    text: pkg.blocks.map((b) => `import ${leanName(b.leanModule)}\n`).join("") || "\n",
  })
  const fns = scanFunctions(pkg)
  return {
    format: 1,
    scope: ["."],
    require: [],
    inputs: "",
    blocks,
    workspace,
    files,
    stray: strayFiles(pkg, expected),
    functions: "functions" in fns ? fns.functions : [],
    ...("error" in fns ? { functions_error: fns.error } : {}),
    proof_inputs: "",
  }
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = []
  for await (const chunk of process.stdin) chunks.push(Buffer.from(chunk))
  return Buffer.concat(chunks).toString("utf8")
}

async function translate(root: string): Promise<unknown> {
  const input: unknown = JSON.parse(await readStdin())
  const given = isRecord(input) ? input["blocks"] : undefined
  placeholderHooks(root)
  const pkg = await readPackage(root)
  const summaries = new Map<string, Summary>()
  if (isRecord(given))
    for (const b of pkg.blocks) {
      const entry = given[blockName(b)]
      const summary = isRecord(entry) ? entry["summary"] : undefined
      if (isRecord(summary))
        summaries.set(b.outFile, {
          public: named(summary["public"]),
          types: named(summary["types"]),
        })
    }
  const t = translatePackage(pkg, summaries)
  return { format: 1, ...t }
}

function option(args: readonly string[], name: string): string | undefined {
  const i = args.indexOf(name)
  const v = i < 0 ? undefined : args[i + 1]
  return v === undefined || v.startsWith("--") ? undefined : v
}

async function main(argv: readonly string[]): Promise<number> {
  const [command, ...rest] = argv
  const root = option(rest, "--root")
  if ((command !== "scan" && command !== "translate") || root === undefined) {
    process.stderr.write(USAGE)
    return 252
  }
  if (!checkVersions()) return 255
  const result = command === "scan" ? await scan(root) : await translate(root)
  process.stdout.write(`${JSON.stringify(result)}\n`)
  return 0
}

try {
  process.exitCode = await main(process.argv.slice(2))
} catch (e) {
  log(e instanceof Error ? e.message : String(e))
  process.exitCode = e instanceof ProjectError ? e.code : 255
}
