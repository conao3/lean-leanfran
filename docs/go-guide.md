# Using leanfran from Go

## Embedded Lean

Use Go 1.26 or later. In your Go module, install the tool and add a top-level block to a Go file.

```sh
go get -tool github.com/conao3/leanfran-go/cmd/leanfran
```

```go
package pricing

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

def width (r : Range) : Nat := r.hi - r.lo

theorem width_le (r : Range) : width r ≤ r.hi := by
  unfold width
  omega
`)
```

Run `go tool leanfran sync` with Lean, Lake, and the compiler on PATH. The compiler is available from `nix build .#go` in the leanfran repository. Add `result/bin` to PATH or pass the compiler's path to `sync`. The Go package can now call `NewRange(big.NewInt(2), big.NewInt(5))` and `Width(r)`, which returns 3. See the [range sample](../langs/Go/samples/embed-range/) for the full call.

Each package has one block, identified by its Go import path. Use a raw or interpreted string literal with `Lean`, or place the source in the same package directory and pass its filename to `LeanFile`. `Imports("Std.Data.HashMap")` imports a Lean module. `Uses("example.com/app/orders")` opens another block's Lean namespace and shares the Go types generated for it. Pass the options after the source. The options return `leanfran.BlockOption`.

### Commands and configuration

| Command | Effect |
| --- | --- |
| `go tool leanfran sync` | Scans the module, builds the Lean sources in `.leanfran/workspace`, and installs all generated packages after the build and generation succeed. |
| `go tool leanfran status` | Checks freshness without Lean or Lake. Reports stale or removed blocks and missing generated files, with exit status 1 when work is needed. |
| `go tool leanfran check` | Runs `sync` and verifies the result with `status`. |

All three commands accept `--dir` to choose a directory within the Go module. The CLI reads the module from that directory and scans its packages. Put `//go:generate go tool leanfran sync` in a Go file to run sync through `go generate`.

The compiler must report the generator version expected by the Go tool. `sync` and `check` look for the compiler through `--leanfran-go`, `LEANFRAN_GO_CLI`, then PATH. Both `lean` and `lake` must match the root `lean-toolchain`. The default is `leanprover/lean4:v4.35.0`.

An optional `leanfran.config.json` at the module root takes a `paths` array of directories to scan and a `require` array of Lake dependencies. Dependency entries use the keys of Lake's `[[require]]` entries. Relative dependency paths start at the Go module root.

```json
{
  "paths": ["pricing", "orders"],
  "require": [{"name": "Domain", "path": "../domain"}]
}
```

Commit each block's `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, `leanfran_lean_gen.go`, and `leanfran.json`. Ignore the module's `.leanfran/` directory. The application and `status` work with the Go toolchain alone. Lean diagnostics point to the original Go literal or Lean file. When a build or proof fails, the previous generated files remain in place.

### Importing Go models

Use `Models(Item{}, Color(""))` to make a Go struct and a named string type available in a block. Lean keeps their Go names, field names, and string constant names. The generated Go functions accept and return the original Go types. Nested model types are imported recursively. A model must be an exported, non-generic Go type. A struct must have explicitly named exported fields, and model references must be acyclic. String models need typed constants with valid UTF-8 in their declaring package. Constants with equal values share a constructor named for the first constant in lexical order.

| Go | Lean |
| --- | --- |
| `int8` through `int64`, `uint8` through `uint64` | Corresponding fixed-width type |
| `int`, `uint` | `Int64`, `UInt64` |
| `*big.Int` | `Int`, or `Nat` with `ge=0` |
| `float64`, `float32`, `bool`, `string`, `rune` | `Float`, `Float32`, `Bool`, `String`, `Char` |
| `[]byte`, `[]T`, `*T` | `ByteArray`, `Array T`, `Option T` |
| Named struct | Lean structure |
| Named string type with typed constants | Lean inductive type with one nullary constructor per distinct value |

Use `leanfran:"ge=1,le=100"` for inclusive integer bounds, `leanfran:"min_len=1"` for a minimum number of Unicode code points, and `leanfran:"min_items=1"` for a minimum slice length. These tags become proof fields such as `Quantity_ge`. An invalid Go value passed to a generated function produces a `*leanfran.ValidationError`. The [models sample](../langs/Go/samples/embed-models/) shares an order between two packages.

## Generating from a compiled Lean module

Build the compiler with `nix build .#go` at the repository root. Use the same Lean toolchain as the compiler to produce the `.olean` files. Place Go and `gofmt` on your PATH and add `github.com/conao3/leanfran-go` to your Go module.

```sh
lean -o Pricing.olean Pricing.lean
leanfran-go module generate --module-name Pricing --search-path . \
  --output-dir pricing
```

The command writes `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, and `leanfran_lean_gen.go`. The package name defaults to the last component of the Lean module name in lowercase. Use `--package` to override it. The module name also supplies the prefix to remove from public names. Set `--namespace` when the Lean declarations use a different prefix. Use `--roots` to select public functions explicitly.

The JSON summary reports the files and the qualified Lean name and reason for each skipped declaration. Use `--output text` for a human-readable summary. Each generation replaces the output files and removes obsolete Go files marked as generated by leanfran-go from the output directory. To compile a runtime-facing package or a command, use `--internal-only --output-file` and add `--main` for commands.

## Public types and functions

Structures have exported fields, including fields inherited from a parent. Enums have a named `string` type and one constant per constructor. Other inductive types have a sealed interface and one struct type per constructor. Proof fields become validation checks. Named subtypes have a `Val` field and anonymous subtypes use their base Go type.

| Lean | Go |
| --- | --- |
| `Nat`, `Int` | `*big.Int` |
| `UInt8` through `UInt64`, `Int8` through `Int64` | Corresponding Go integer type |
| `USize`, `ISize` | `uint64`, `int64` |
| `Fin n` | `uint64` through a bound of 2⁶⁴ and `*big.Int` for larger bounds |
| `Float`, `Float32` | `float64`, `float32` |
| `Bool`, `String`, `Char`, `Unit` | `bool`, `string`, `rune`, `struct{}` |
| `Option α` | `*T`, with nil for `none` |
| `List α`, `Array α`, `ByteArray` | `[]T`, `[]T`, `[]byte` |
| `α × β` | `leanfran.Pair[A, B]` |
| `Except ε α` as a field or argument | `leanfran.Except[E, A]` with `Error *E` and `Ok A` |

Use Go literals or `New<Type>` for types with invariants. Constructors, `Validate`, JSON decoding, and generated functions check Lean invariants and constraints such as nonnegative naturals, valid UTF-8, and Unicode scalar values. Generated functions return `(T, error)` or `error` for `Unit`. Use `errors.As` to inspect `*leanfran.ValidationError`, `*leanfran.ExceptError[E]`, and `*leanfran.IOError`. A validation error contains issues with a message and path for each failing field or parameter. Lean runtime failures such as unreachable IR propagate as `*rt.InternalPanic`.

```go
d, err := pricing.NewDiscountPercent(big.NewInt(10))
if err != nil {
    return err
}
total, err := pricing.Total([]*big.Int{big.NewInt(1200), big.NewInt(800)}, d)
```

Generated functions can run concurrently. Each call copies input data into Lean's runtime representation and copies the result back into Go. During a call, synchronize any mutations of data shared with the call.

To reuse public types from a generated library, use `--type-module Library.Namespace=example.com/myapp/library` when generating the consumer. Generate both packages using the Lean namespace on the left as the library's naming prefix. The consumer imports the library's Go types and conversion functions.

## JSON and JSON Schema

Generated types implement `json.Marshaler`. Use `json.Unmarshal` for structs, enums, and a known constructor. For an interface, use `Unmarshal<Type>(data)` to select the constructor from JSON.

Lean JSON conventions include decimal strings for `UInt64` and `USize`, numbers for unbounded integers, arrays for products and bytes, and externally tagged objects such as `{"percent":{"p":10}}` for constructors with fields. Constructors with no fields are strings. A named structure field such as `note?` is emitted as `note` when present and omitted otherwise. JSON uses `null` for both `none` and `some none` in nested options. The Go representation preserves both cases across calls into Lean.

Call a generated value's `JSONSchema(target)` method with `draft-2020-12`, `draft-07`, or `openapi-3.0`. Some proof constraints appear as numeric or length bounds. Call `Validate` to evaluate arbitrary decidable invariants. `LeanfranDesc()` exposes the type descriptor used by the generated code.

## Skipped definitions

The public generator accepts concrete data types and monomorphic functions. The summary identifies indexed families, type classes, propositions, private declarations, constructors with type fields, and propositions without a synthesizable `Decidable` instance. The public layer also skips function-valued types and types from the `Std`, `Lean`, `IO`, and `System` namespaces, along with `Thunk` and `Task`. Public functions can return `IO` results.
