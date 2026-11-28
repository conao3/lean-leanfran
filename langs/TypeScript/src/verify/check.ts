import { spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import { readFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import {
  type ArrowFunctionExpression,
  type Expression,
  type Function as FunctionNode,
  parseSync,
  type Program,
  Visitor,
} from "oxc-parser"
import { type Json } from "../key.ts"
import { leanIdent as modelIdent } from "../models.ts"
import {
  aliasFile,
  type Block,
  isRecord,
  leanName,
  moduleParts,
  type Package,
  type Summary,
} from "../project.ts"
import { resolve as resolveDesc, type TypeDesc } from "../runtime/marshal.ts"
import { posixRelative, ProjectError, tsFiles } from "../scan.ts"
import {
  astHash,
  BIG,
  BOOL,
  type FieldType,
  Fn,
  ident,
  leanType,
  NUM,
  type Located,
  STR,
  Translator,
  TranslateError,
  type TsType,
  type TypeResolver,
} from "./translate.ts"

function isDesc(x: unknown): x is TypeDesc {
  return isRecord(x) && typeof x["kind"] === "string"
}

interface Import {
  readonly from: string
  readonly exportName: string | null
}

export interface SpecRef {
  readonly exportName: string
  readonly outFile: string
  readonly at: number
}

export interface ModelCall {
  readonly file: string
  readonly module: string
  readonly fn: string
  readonly fnNode: FunctionNode | ArrowFunctionExpression
  readonly refines: SpecRef | undefined
  readonly requires: SpecRef | undefined
  readonly ensures: readonly (readonly [string, SpecRef])[]
  readonly hash: string
  readonly at: number
}

export interface Source extends Located {
  readonly module: string
  readonly program: Program
  readonly imports: ReadonlyMap<string, Import>
  readonly fns: ReadonlyMap<string, FunctionNode | ArrowFunctionExpression>
  readonly models: readonly ModelCall[]
}

function lineStarts(text: string): number[] {
  const starts = [0]
  for (let i = 0; i < text.length; i++) if (text[i] === "\n") starts.push(i + 1)
  return starts
}

function locator(file: string, text: string): (offset: number) => string {
  const starts = lineStarts(text)
  return (offset) => {
    let lo = 0
    let hi = starts.length - 1
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1
      if ((starts[mid] ?? 0) <= offset) lo = mid
      else hi = mid - 1
    }
    return `${file}:${lo + 1}:${offset - (starts[lo] ?? 0) + 1}`
  }
}

function tsSpecifierFile(file: string, spec: string): string {
  return resolve(dirname(file), spec)
}

export function readSource(root: string, file: string): Source {
  const text = readFileSync(file, "utf8")
  const where = locator(file, text)
  const parsed = parseSync(file, text, { lang: "ts", sourceType: "module", preserveParens: false })
  const err = parsed.errors[0]
  if (err !== undefined)
    throw new ProjectError(`${where(err.labels[0]?.start ?? 0)}: cannot parse: ${err.message}`, 254)
  const imports = new Map<string, Import>()
  const fns = new Map<string, FunctionNode | ArrowFunctionExpression>()
  const modelNames = new Set<string>()
  const verifyNamespaces = new Set<string>()
  for (const s of parsed.program.body) {
    if (s.type === "ImportDeclaration") {
      const from = s.source.value.startsWith(".")
        ? tsSpecifierFile(file, s.source.value)
        : s.source.value
      for (const sp of s.specifiers) {
        if (sp.type === "ImportNamespaceSpecifier")
          imports.set(sp.local.name, { from, exportName: null })
        else if (sp.type === "ImportSpecifier") {
          const name = sp.imported.type === "Literal" ? sp.imported.value : sp.imported.name
          imports.set(sp.local.name, { from, exportName: name })
          if (from === "leanfran/verify" && name === "model") modelNames.add(sp.local.name)
        }
        if (sp.type === "ImportNamespaceSpecifier" && from === "leanfran/verify")
          verifyNamespaces.add(sp.local.name)
      }
      continue
    }
    const d = s.type === "ExportNamedDeclaration" ? s.declaration : s
    if (d === null) continue
    if (d.type === "FunctionDeclaration" && d.id !== null) fns.set(d.id.name, d)
    if (d.type === "VariableDeclaration" && d.kind === "const")
      for (const x of d.declarations)
        if (x.id.type === "Identifier" && x.init?.type === "ArrowFunctionExpression")
          fns.set(x.id.name, x.init)
  }
  const module = posixRelative(root, file)
  const models: ModelCall[] = []
  const specRef = (e: Expression, label: string): SpecRef => {
    const bad = (): never => {
      throw new ProjectError(
        `${where(e.start)}: the ${label} specification must be a function of a generated module (a named import or a property of a namespace import of _lean/)`,
        254,
      )
    }
    if (e.type === "Identifier") {
      const i = imports.get(e.name)
      if (i === undefined || i.exportName === null) return bad()
      return { exportName: i.exportName, outFile: i.from, at: e.start }
    }
    if (
      e.type === "MemberExpression" &&
      !e.computed &&
      e.object.type === "Identifier" &&
      e.property.type === "Identifier"
    ) {
      const i = imports.get(e.object.name)
      if (i === undefined || i.exportName !== null) return bad()
      return { exportName: e.property.name, outFile: i.from, at: e.start }
    }
    return bad()
  }
  new Visitor({
    CallExpression(c) {
      const f = c.callee
      const isModel =
        (f.type === "Identifier" && modelNames.has(f.name)) ||
        (f.type === "MemberExpression" &&
          !f.computed &&
          f.object.type === "Identifier" &&
          verifyNamespaces.has(f.object.name) &&
          f.property.type === "Identifier" &&
          f.property.name === "model")
      if (!isModel) return
      const [target, options, ...rest] = c.arguments
      if (
        target?.type !== "Identifier" ||
        options?.type !== "ObjectExpression" ||
        rest.length !== 0
      )
        throw new ProjectError(
          `${where(c.start)}: model takes a function of the module and an object literal`,
          254,
        )
      const fnNode = fns.get(target.name)
      if (fnNode === undefined)
        throw new ProjectError(
          `${where(target.start)}: ${target.name} must be a function declaration or a const arrow function of the module`,
          254,
        )
      let refines: SpecRef | undefined
      let requires: SpecRef | undefined
      const ensures: [string, SpecRef][] = []
      for (const p of options.properties) {
        if (p.type !== "Property" || p.computed || p.key.type !== "Identifier")
          throw new ProjectError(
            `${where(p.start)}: the options of model must be plain properties`,
            254,
          )
        if (p.key.name === "refines") refines = specRef(p.value, "refines")
        else if (p.key.name === "requires") requires = specRef(p.value, "requires")
        else if (p.key.name === "ensures") {
          if (p.value.type !== "ObjectExpression")
            throw new ProjectError(
              `${where(p.value.start)}: ensures must be an object literal of labelled specifications`,
              254,
            )
          for (const q of p.value.properties) {
            if (q.type !== "Property" || q.computed || q.key.type !== "Identifier")
              throw new ProjectError(`${where(q.start)}: the labels of ensures must be names`, 254)
            if (
              !/^[A-Za-z_][A-Za-z0-9_]*$/u.test(q.key.name) ||
              q.key.name === "refines" ||
              q.key.name === "returnsNat"
            )
              throw new ProjectError(
                `${where(q.start)}: ${q.key.name} cannot be a label of ensures`,
                254,
              )
            ensures.push([q.key.name, specRef(q.value, q.key.name)])
          }
        } else
          throw new ProjectError(`${where(p.start)}: unknown option ${p.key.name} of model`, 254)
      }
      models.push({
        file,
        module,
        fn: target.name,
        fnNode,
        refines,
        requires,
        ensures,
        hash: createHash("sha256")
          .update(astHash({ fn: fnNode, options }))
          .digest("hex"),
        at: c.start,
      })
    },
  }).visit(parsed.program)
  return { file, where, module, program: parsed.program, imports, fns, models }
}

export function readSources(root: string): Source[] {
  return tsFiles(join(root, "src")).map((f) => readSource(root, f))
}

function blockOf(pkg: Package, file: string): Block | undefined {
  const f = file.endsWith(".ts") ? file : `${file}.ts`
  return (
    pkg.blocks.find((b) => b.outFile === f) ??
    pkg.blocks.find(
      (b) => aliasFile(b) === f && pkg.blocks.filter((x) => x.module === b.module).length === 1,
    )
  )
}

function specBlock(pkg: Package, src: Source, ref: SpecRef): Block {
  const b = blockOf(pkg, ref.outFile)
  if (b === undefined)
    throw new ProjectError(
      `${src.where(ref.at)}: ${ref.outFile} is not a module generated from a lean(...) block`,
      254,
    )
  return b
}

function specHash(pkg: Package, src: Source, m: ModelCall): string {
  const refs = [m.refines, m.requires, ...m.ensures.map(([, r]) => r)].filter(
    (r) => r !== undefined,
  )
  const keys = [...new Set(refs.map((r) => specBlock(pkg, src, r).key))].toSorted()
  return createHash("sha256")
    .update(JSON.stringify({ fn: m.hash, blocks: keys }))
    .digest("hex")
}

export function modelModule(module: string): string[] {
  return ["LeanTsModel", ...moduleParts(module)]
}

function qualified(m: ModelCall): string {
  return `${m.module}:${m.fn}`
}

type Descs = Map<string, Map<string, TypeDesc>>

const DESCS_CHILD = `
import { pathToFileURL } from "node:url"
const ser = (d0, stack) => {
  let d = d0
  while (d.kind === "ref") d = d.get()
  if ((d.kind === "struct" || d.kind === "inductive") && stack.includes(d.name)) return { kind: "recursive", name: d.name }
  const st = d.kind === "struct" || d.kind === "inductive" ? [...stack, d.name] : stack
  const v = (x) => ({ name: x.name, fields: x.fields.map((f) => ({ key: f.key, omitNone: f.omitNone, flat: f.flat, desc: ser(f.desc, st) })) })
  switch (d.kind) {
    case "list": case "array": case "option": return { ...d, item: ser(d.item, st) }
    case "prod": return { kind: "prod", fst: ser(d.fst, st), snd: ser(d.snd, st) }
    case "except": return { kind: "except", error: ser(d.error, st), value: ser(d.value, st) }
    case "struct": return { kind: "struct", name: d.name, trivial: d.trivial, variant: v(d.variant) }
    case "inductive": return { kind: "inductive", name: d.name, tagKey: d.tagKey, variants: d.variants.map(v) }
    case "subtype": return { kind: "subtype", name: d.name, base: ser(d.base, st) }
    case "model": return { kind: "model", name: d.name, key: d.key }
    case "fin": return { kind: "fin", bound: String(d.bound) }
    default: return { kind: d.kind, ...(d.bits === undefined ? {} : { bits: d.bits }), ...(d.name === undefined ? {} : { name: d.name }), ...(d.ctors === undefined ? {} : { ctors: d.ctors }) }
  }
}
const [first, ...files] = JSON.parse(process.argv[1])
for (const f of first) await import(pathToFileURL(f).href)
const out = {}
for (const f of files) {
  const m = await import(pathToFileURL(f).href)
  out[f] = {}
  for (const [k, x] of Object.entries(m)) {
    const d = (typeof x === "object" && x !== null) || typeof x === "function" ? x.desc : undefined
    if (typeof d === "object" && d !== null && typeof d.kind === "string") out[f][k] = ser(d, [])
  }
}
process.stdout.write(JSON.stringify(out))
`

function loadDescs(pkg: Package, sources: readonly Source[]): Descs {
  const users = sources.filter((s) => s.models.length !== 0)
  const files = new Set<string>()
  for (const s of users)
    for (const i of s.imports.values())
      if (blockOf(pkg, i.from) !== undefined)
        files.add(i.from.endsWith(".ts") ? i.from : `${i.from}.ts`)
  const out: Descs = new Map()
  if (files.size === 0) return out
  const r = spawnSync(
    process.execPath,
    [
      "--input-type=module",
      "-e",
      DESCS_CHILD,
      JSON.stringify([users.map((s) => s.file), ...files]),
    ],
    { encoding: "utf8", maxBuffer: 1 << 28 },
  )
  if (r.status !== 0)
    throw new ProjectError(`reading the types of the generated modules: ${r.stderr}`, 254)
  const parsed: unknown = JSON.parse(r.stdout)
  if (!isRecord(parsed))
    throw new ProjectError("reading the types of the generated modules returned no object", 255)
  for (const [f, ds] of Object.entries(parsed)) {
    const m = new Map<string, TypeDesc>()
    if (isRecord(ds)) for (const [k, d] of Object.entries(ds)) if (isDesc(d)) m.set(k, d)
    out.set(f, m)
  }
  return out
}

function descType(d: TypeDesc, names: ReadonlyMap<string, string>, seen: Set<string>): TsType {
  const r = resolveDesc(d)
  const fields = (
    fs: readonly { key: string; desc: TypeDesc; omitNone: boolean; flat: boolean }[],
  ): FieldType[] =>
    fs.flatMap((f): FieldType[] => {
      if (f.flat) {
        const inner = descType(f.desc, names, seen)
        return inner.k === "struct" ? [...inner.fields] : []
      }
      const fr = resolveDesc(f.desc)
      return [
        {
          key: f.key,
          lean: f.omitNone ? `${f.key}?` : f.key,
          type: descType(f.desc, names, seen),
          nat: fr.kind === "nat",
        },
      ]
    })
  const leanOf = (name: string): string => {
    const l = names.get(name)
    if (l === undefined) throw new TranslateError(`the Lean name of the type ${name} is unknown`)
    return l
  }
  switch (r.kind) {
    case "nat":
    case "int":
      return BIG
    case "bool":
      return BOOL
    case "string":
      return STR
    case "list":
      return { k: "list", item: descType(r.item, names, seen) }
    case "option":
      return { k: "opt", item: descType(r.item, names, seen), absent: r.absent }
    case "prod":
      return { k: "tuple", items: [descType(r.fst, names, seen), descType(r.snd, names, seen)] }
    case "struct":
      if (seen.has(r.name))
        throw new TranslateError(`the recursive type ${r.name} is outside the subset`)
      return { k: "struct", lean: leanOf(r.name), ts: r.name, fields: fields(r.variant.fields) }
    case "enum":
      return { k: "enum", lean: leanOf(r.name), ts: r.name, ctors: r.ctors }
    case "inductive": {
      if (seen.has(r.name))
        throw new TranslateError(`the recursive type ${r.name} is outside the subset`)
      const inner = new Set([...seen, r.name])
      return {
        k: "ind",
        lean: leanOf(r.name),
        ts: r.name,
        tagKey: r.tagKey,
        variants: r.variants.map((v) => ({
          name: v.name,
          fields: v.fields.map((f) => ({
            key: f.key,
            lean: f.key,
            type: descType(f.desc, names, inner),
            nat: resolveDesc(f.desc).kind === "nat",
          })),
        })),
      }
    }
    default:
      throw new TranslateError(`the Lean type of kind ${r.kind} is outside the subset`)
  }
}

function nullableOf(
  s: Readonly<Record<string, unknown>>,
): Readonly<Record<string, unknown>> | undefined {
  const any = s["anyOf"]
  if (Array.isArray(any) && any.length === 2) {
    const other = any.find((x: unknown) => !(isRecord(x) && x["type"] === "null"))
    if (isRecord(other) && any.some((x: unknown) => isRecord(x) && x["type"] === "null"))
      return other
  }
  const t = s["type"]
  if (Array.isArray(t) && t.length === 2 && t.includes("null"))
    return { ...s, type: t.find((x: unknown) => x !== "null") }
  return undefined
}

function jsonType(s: unknown, where: string): { t: TsType; nat: boolean } {
  if (!isRecord(s)) throw new TranslateError(`${where}: a property schema is not an object`)
  const min = s["minimum"]
  const ex = s["exclusiveMinimum"]
  const lo = typeof min === "number" ? min : typeof ex === "number" ? Math.floor(ex) + 1 : undefined
  switch (s["type"]) {
    case "integer":
      return { t: NUM, nat: lo !== undefined && lo >= 0 }
    case "string":
      return { t: STR, nat: false }
    case "boolean":
      return { t: BOOL, nat: false }
    case "array":
      return { t: { k: "list", item: jsonType(s["items"], where).t }, nat: false }
    default:
      throw new TranslateError(
        `${where}: the model property ${JSON.stringify(s)} is outside the subset leanfran translates`,
      )
  }
}

export function modelStruct(json: Json, lean: string, ts: string, where: string): TsType {
  if (!isRecord(json) || !isRecord(json["properties"]))
    throw new TranslateError(`${where}: the model ${ts} is not an object schema`)
  const req = json["required"]
  const required = new Set(Array.isArray(req) ? req.filter((x) => typeof x === "string") : [])
  const fields: FieldType[] = Object.entries(json["properties"]).map(([key, raw]) => {
    if (!isRecord(raw))
      throw new TranslateError(`${where}: the property ${key} of ${ts} is not an object`)
    const inner = nullableOf(raw)
    const { t, nat } = jsonType(inner ?? raw, where)
    if (!required.has(key))
      return { key, lean: `${key}?`, type: { k: "opt", item: t, absent: "undefined" }, nat: false }
    if (inner !== undefined)
      return { key, lean: key, type: { k: "opt", item: t, absent: "null" }, nat: false }
    return { key, lean: key, type: t, nat }
  })
  return { k: "struct", lean, ts, fields }
}

export function typeResolver(
  pkg: Package,
  src: Source,
  summaries: ReadonlyMap<string, Summary> | undefined,
  descs: Descs | undefined,
): TypeResolver {
  return {
    reference(name, qualifier, at) {
      const local = qualifier ?? name
      const i = src.imports.get(local)
      if (i === undefined) return undefined
      const exportName =
        qualifier === undefined ? i.exportName : i.exportName === null ? name : undefined
      if (exportName === undefined || exportName === null) return undefined
      if (i.from === "leanfran/schema" && (exportName === "Nat" || exportName === "Int")) return BIG
      const b = blockOf(pkg, i.from)
      if (b === undefined) return undefined
      if (summaries === undefined || descs === undefined)
        return { k: "struct", lean: exportName, ts: exportName, fields: [] }
      const summary = summaries.get(b.outFile)
      const d = descs.get(i.from.endsWith(".ts") ? i.from : `${i.from}.ts`)?.get(exportName)
      if (summary === undefined || d === undefined)
        throw new TranslateError(
          `${src.where(at)}: ${exportName} is not a type generated from ${b.name}`,
        )
      const names = new Map(summary.types.map((t) => [t.typescript, t.lean]))
      return descType(d, names, new Set())
    },
    model(name, at) {
      const i = src.imports.get(name)
      const from = i === undefined ? src.file : i.from
      const exportName = i === undefined ? name : i.exportName
      for (const b of pkg.blocks)
        for (const m of b.models)
          if (m.from === from && m.exportName === exportName) {
            const json = b.inputs.models[m.name]
            if (json === undefined)
              throw new TranslateError(`${src.where(at)}: no JSON Schema of the model ${m.name}`)
            const lean = `${leanName(["LeanTsModels", ...moduleParts(b.module)])}.${modelIdent(m.name)}`
            return modelStruct(json, lean, m.name, src.where(at))
          }
      return undefined
    },
  }
}

interface SpecName {
  readonly lean: string
  readonly module: string
}

function specName(
  pkg: Package,
  src: Source,
  ref: SpecRef,
  summaries: ReadonlyMap<string, Summary>,
): SpecName {
  const b = specBlock(pkg, src, ref)
  const p = summaries.get(b.outFile)?.public.find((x) => x.typescript === ref.exportName)
  if (p === undefined)
    throw new ProjectError(
      `${src.where(ref.at)}: ${ref.exportName} is not a public function of the block ${b.name}`,
      254,
    )
  return { lean: p.lean, module: leanName(b.leanModule) }
}

function obligations(
  m: ModelCall,
  fn: Fn,
  pkg: Package,
  src: Source,
  summaries: ReadonlyMap<string, Summary>,
): { props: Map<string, string>; imports: Set<string> } {
  const binders = fn.params.map((p) => `(${ident(p.name)} : ${p.nat ? "Nat" : leanType(p.type)})`)
  const args = fn.params.map((p) => ident(p.name)).join(" ")
  const a = args === "" ? "" : ` ${args}`
  const call = `(${ident(fn.name)}${a})`
  const imports = new Set<string>()
  const spec = (r: SpecRef): string => {
    const n = specName(pkg, src, r, summaries)
    imports.add(n.module)
    return `_root_.${n.lean}`
  }
  const pre = m.requires === undefined ? "" : `${spec(m.requires)}${a} = true → `
  const wrap = (body: string): string =>
    binders.length === 0 ? `${pre}${body}` : `∀ ${binders.join(" ")}, ${pre}${body}`
  const ret = leanType(fn.ret)
  const props = new Map<string, string>()
  if (m.refines !== undefined) {
    const expected = `(${spec(m.refines)}${a} : ${ret})`
    props.set(
      "refines",
      wrap(fn.fails ? `${call} = Except.ok ${expected}` : `${call} = ${expected}`),
    )
  }
  for (const [label, r] of m.ensures) {
    const e = spec(r)
    props.set(
      label,
      wrap(fn.fails ? `∀ r, ${call} = Except.ok r → ${e}${a} r = true` : `${e}${a} ${call} = true`),
    )
  }
  if (fn.retNat)
    props.set("returnsNat", wrap(fn.fails ? `∀ r, ${call} = Except.ok r → 0 ≤ r` : `0 ≤ ${call}`))
  return { props, imports }
}

function modeOf(t: TsType): "n" | "_" | "mixed" {
  const kinds = new Set<string>()
  const walk = (x: TsType): void => {
    if (x.k === "num" || x.k === "big") kinds.add(x.k)
    else if (x.k === "list" || x.k === "opt") walk(x.item)
    else if (x.k === "tuple") x.items.forEach(walk)
    else if (x.k === "struct") x.fields.forEach((f) => walk(f.type))
    else if (x.k === "ind") x.variants.forEach((v) => v.fields.forEach((f) => walk(f.type)))
  }
  walk(t)
  if (kinds.has("num") && kinds.has("big")) return "mixed"
  return kinds.has("num") ? "n" : "_"
}

export interface SourceError {
  readonly file: string
  readonly line: number
  readonly column: number
  readonly message: string
}

export interface ScannedFunction {
  readonly id: string
  readonly labels: readonly string[]
  readonly hash: string
  readonly origin: { readonly file: string; readonly line: number; readonly column: number }
  readonly data: Json
}

export interface ModelModuleOut {
  readonly module: string
  readonly path: string
  readonly text: string
  readonly functions: readonly string[]
}

export interface TranslatedFunction {
  readonly id: string
  readonly model: string
  readonly dependencies: readonly string[]
  readonly error?: SourceError
  readonly data: Json
}

export interface Translation {
  readonly modules: readonly ModelModuleOut[]
  readonly aggregates: readonly Omit<ModelModuleOut, "functions">[]
  readonly functions: readonly TranslatedFunction[]
}

function originOf(root: string, src: Source, offset: number): ScannedFunction["origin"] {
  const m = /^(.*):(\d+):(\d+)$/u.exec(src.where(offset))
  return {
    file: posixRelative(root, src.file),
    line: Number(m?.[2] ?? 1),
    column: Number(m?.[3] ?? 1),
  }
}

export function errorOf(
  root: string,
  e: unknown,
  fallback: ScannedFunction["origin"],
  fn?: string,
): SourceError {
  const text = e instanceof Error ? e.message : String(e)
  const m = /^(.+?):(\d+):(\d+): ([\s\S]*)$/u.exec(text)
  const strip = (msg: string): string =>
    fn !== undefined && msg.startsWith(`${fn}: `) ? msg.slice(fn.length + 2) : msg
  if (m === null) return { ...fallback, message: strip(text) }
  const file = m[1] ?? ""
  return {
    file: file.startsWith("/") ? posixRelative(root, file) : file,
    line: Number(m[2]),
    column: Number(m[3]),
    message: strip(m[4] ?? ""),
  }
}

function labelsOf(pkg: Package, src: Source, m: ModelCall): string[] {
  let retNat = false
  try {
    retNat = new Fn(m.fn, m.fnNode, src, typeResolver(pkg, src, undefined, undefined)).retNat
  } catch (e) {
    if (!(e instanceof ProjectError)) throw e
  }
  return [
    ...(m.refines === undefined ? [] : ["refines"]),
    ...m.ensures.map(([l]) => l),
    ...(retNat ? ["returnsNat"] : []),
  ]
}

export function scanFunctions(
  pkg: Package,
): { readonly functions: readonly ScannedFunction[] } | { readonly error: SourceError } {
  try {
    const out: ScannedFunction[] = []
    for (const src of readSources(pkg.root)) {
      const seen = new Set<string>()
      for (const m of src.models) {
        if (seen.has(m.fn))
          throw new ProjectError(`${src.where(m.at)}: ${m.fn} has two model(...) calls`, 254)
        seen.add(m.fn)
        out.push({
          id: qualified(m),
          labels: labelsOf(pkg, src, m),
          hash: specHash(pkg, src, m),
          origin: originOf(pkg.root, src, m.fnNode.start),
          data: {},
        })
      }
    }
    return { functions: out }
  } catch (e) {
    if (!(e instanceof ProjectError)) throw e
    return { error: errorOf(pkg.root, e, { file: "", line: 0, column: 0 }) }
  }
}

function calls(node: unknown, names: ReadonlySet<string>, out: Set<string>): void {
  if (Array.isArray(node)) {
    for (const x of node) calls(x, names, out)
    return
  }
  if (!isRecord(node)) return
  const callee = node["callee"]
  if (
    node["type"] === "CallExpression" &&
    isRecord(callee) &&
    callee["type"] === "Identifier" &&
    typeof callee["name"] === "string" &&
    names.has(callee["name"])
  )
    out.add(callee["name"])
  for (const v of Object.values(node)) if (typeof v === "object" && v !== null) calls(v, names, out)
}

export function translatePackage(
  pkg: Package,
  summaries: ReadonlyMap<string, Summary>,
): Translation {
  const sources = readSources(pkg.root).filter((s) => s.models.length !== 0)
  const descs = loadDescs(pkg, sources)
  const modules: ModelModuleOut[] = []
  const functions: TranslatedFunction[] = []
  for (const src of sources) {
    const types = typeResolver(pkg, src, summaries, descs)
    const parts = modelModule(src.module)
    const ns = leanName(parts)
    const failures = new Map<string, SourceError>()
    const fail = (m: ModelCall, e: unknown): void => {
      if (!(e instanceof ProjectError)) throw e
      failures.set(m.fn, errorOf(pkg.root, e, originOf(pkg.root, src, m.fnNode.start), m.fn))
    }
    let fns: { readonly m: ModelCall; readonly fn: Fn }[] = []
    for (const m of src.models) {
      try {
        fns.push({ m, fn: new Fn(m.fn, m.fnNode, src, types) })
      } catch (e) {
        fail(m, e)
      }
    }
    let defs = new Map<string, string>()
    for (;;) {
      const tr = new Translator(
        fns.map((x) => x.fn),
        types,
      )
      const bad: [ModelCall, unknown][] = []
      for (let round = 0; round <= fns.length + 1; round++) {
        const before = fns.map((x) => x.fn.fails).join()
        defs = new Map()
        bad.length = 0
        for (const x of fns) {
          try {
            defs.set(x.m.fn, tr.definition(x.fn))
          } catch (e) {
            bad.push([x.m, e])
          }
        }
        if (bad.length !== 0 || fns.map((x) => x.fn.fails).join() === before) break
      }
      if (bad.length === 0) break
      for (const [m, e] of bad) fail(m, e)
      fns = fns.filter((x) => !failures.has(x.m.fn))
    }
    const imports = new Set(["LeanTsLib"])
    for (const i of src.imports.values()) {
      const b = blockOf(pkg, i.from)
      if (b !== undefined) imports.add(leanName(b.leanModule))
    }
    const names = new Set(fns.map((x) => x.m.fn))
    const body: string[] = []
    const ids: string[] = []
    for (const { m, fn } of fns) {
      let o: ReturnType<typeof obligations>
      let csimp: Json = {}
      const modes = fn.params.map((p) => modeOf(p.type))
      try {
        o = obligations(m, fn, pkg, src, summaries)
        if (m.refines !== undefined && m.requires === undefined && !modes.includes("mixed")) {
          const n = specName(pkg, src, m.refines, summaries)
          const csimpParts = ["LeanTsCsimp", ...moduleParts(src.module)]
          csimp = {
            csimp: {
              spec: n.lean,
              module: n.module,
              modes,
              path: `${csimpParts.join("/")}.lean`,
              namespace: leanName(csimpParts),
              name: ident(m.fn),
            },
          }
        }
      } catch (e) {
        fail(m, e)
        continue
      }
      const target = `ts:${m.module}#${m.fn}(${modes.map((x) => (x === "mixed" ? "_" : x)).join(",")})`
      body.push(
        `/-- \`${m.module}\` ${m.fn}, translated from TypeScript. -/\n@[extern ${JSON.stringify(target)}]\n${defs.get(m.fn) ?? ""}`,
      )
      for (const i of o.imports) imports.add(i)
      for (const [label, prop] of o.props)
        body.push(`abbrev ${ident(m.fn)}.obligation.${label} : Prop :=\n  ${prop}`)
      const called = new Set<string>()
      calls(m.fnNode.body, names, called)
      called.delete(m.fn)
      functions.push({
        id: qualified(m),
        model: `${parts.join(".")}.${m.fn}`,
        dependencies: [...called].toSorted().map((f) => `${m.module}:${f}`),
        data: csimp,
      })
      ids.push(qualified(m))
    }
    for (const m of src.models) {
      const error = failures.get(m.fn)
      if (error !== undefined)
        functions.push({ id: qualified(m), model: "", dependencies: [], error, data: {} })
    }
    if (ids.length === 0) continue
    modules.push({
      module: parts.join("."),
      path: `${parts.join("/")}.lean`,
      text:
        [...imports]
          .toSorted()
          .map((i) => `import ${i}\n`)
          .join("") + `\nnamespace ${ns}\n\n${body.join("\n\n")}\n\nend ${ns}\n`,
      functions: ids,
    })
  }
  const aggregates =
    modules.length === 0
      ? []
      : [
          {
            module: "LeanTsModel",
            path: "LeanTsModel.lean",
            text: modules.map((m) => `import ${m.module}\n`).join(""),
          },
        ]
  return { modules, aggregates, functions }
}
