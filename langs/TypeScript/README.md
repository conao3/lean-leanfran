# TypeScript

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) for TypeScript: write Lean blocks with `lean(...)`, use generated TypeScript types and Standard Schema values, and verify supported TypeScript functions against Lean specifications.

## Install

```sh
pnpm add leanfran
nix profile install 'github:conao3/lean-leanfran#typescript'
```

Generation requires Lean 4.35.0 (`lean` and `lake`) on `PATH`. Generated modules run in Node 22.18 or later, Bun and browsers with the npm package.

## First Lean block

Put this in `src/arith.ts`:

```ts
import { lean } from "leanfran"
import * as arith from "./_lean/arith.ts"

export const arithBlock = lean(
  "arith",
  String.raw`
def double (n : Nat) : Nat := n + n

theorem double_eq (n : Nat) : double n = 2 * n := by
  unfold double; omega
`,
)

arith.double(21n) // 42n
```

Generate modules from the package root:

```sh
leanfran sync --package .
```

Commit `src/_lean/` and `.leanfran/blocks.json`. Run sync again when you change a block; `leanfran status --package .` checks whether generated code is current.

## Next steps

- [Full TypeScript guide](https://github.com/conao3/lean-leanfran/blob/master/docs/typescript-guide.md): schemas, host models, verification, CLI, runtime semantics and limitations.
- [Samples](https://github.com/conao3/lean-leanfran/blob/master/langs/TypeScript/samples/README.md), including a pricing API and step-by-step examples.
- [Development](https://github.com/conao3/lean-leanfran/blob/master/CONTRIBUTING.md) and [implementation notes](https://github.com/conao3/lean-leanfran/blob/master/docs/typescript-development.md).
