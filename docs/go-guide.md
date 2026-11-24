# Using leanfran from Go

## Embedded Lean

Nix can install the `leanfran-go` compiler from any directory.

```sh
nix profile install 'github:conao3/lean-leanfran#go'
```

Add `lean`, `lake`, and `leanfran-go` to your PATH. Use Lean and Lake from Lean 4.35.0 and match the compiler's release to the Go module version. For a pinned release such as `v0.9.0`, install the compiler from `github:conao3/lean-leanfran/v0.9.0#go` and add the same `@v0.9.0` suffix to `go get -tool`.

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

Run `go tool leanfran sync`. The Go package can now call `NewRange(big.NewInt(2), big.NewInt(5))` and `Width(r)`, which returns 3. See the [range sample](../langs/Go/samples/embed-range/) for the full call.

Each package has one block, identified by its Go import path. Use a raw or interpreted string literal with `Lean`, or place the source in the same package directory and pass its filename to `LeanFile`. `Imports("Std.Data.HashMap")` imports a Lean module. `Uses("example.com/app/orders")` opens another block's Lean namespace and shares the Go types generated for it. Pass the options after the source. The options return `leanfran.BlockOption`.

### Use the compiler from a flake

Add leanfran as a flake input and include its Go compiler in your development shell. Set `system` to `aarch64-darwin` on Apple Silicon.

```nix
{
  inputs = {
    leanfran.url = "github:conao3/lean-leanfran";
    nixpkgs.follows = "leanfran/nixpkgs";
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.go pkgs.lean4 inputs.leanfran.packages.${system}.go ];
      };
    };
}
```

Run `nix develop` from the application's flake directory. Pin `leanfran.url` to the same release tag as the Go module for reproducible compiler and tool versions.

### Commands and configuration

| Command | Effect |
| --- | --- |
| `go tool leanfran sync` | Scans the module, builds the Lean sources in `.leanfran/workspace`, and installs all generated packages after the build and generation succeed. |
| `go tool leanfran status` | Checks freshness without Lean or Lake. Reports stale or removed blocks and missing generated files, with exit status 1 when work is needed. |
| `go tool leanfran check` | Runs `sync` and verifies the result with `status`. |

All three commands accept `--dir` to choose a directory within the Go module. The CLI reads the module from that directory and scans its packages.

`sync` and `check` look for the compiler through `--leanfran-go`, `LEANFRAN_GO_CLI`, then PATH. The compiler must match the Go module release and the tool's generator version. The compiler, `lean`, and `lake` must all match the module's `lean-toolchain`. The default is `leanprover/lean4:v4.35.0`. Use `--verbose` on `sync` or `check` to include Lake trace lines in build diagnostics.

An optional `leanfran.config.json` at the module root takes a `paths` array of directories to scan and a `require` array of Lake dependencies. Dependency entries use the keys of Lake's `[[require]]` entries. Relative dependency paths start at the Go module root.

```json
{
  "paths": ["pricing", "orders"],
  "require": [{"name": "Domain", "path": "../domain"}]
}
```

Commit each block's `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, `leanfran_lean_gen.go`, and `leanfran.json`. Ignore the module's `.leanfran/` directory. The application and `status` work with the Go toolchain alone. Lean diagnostics point to the original Go literal or Lean file. When a build or proof fails, the previous generated files remain in place.

### Check generated files in CI

The freshness check for committed files requires only Go.

```sh
go tool leanfran status
```

Use a clean checkout with Lean, Lake, and the compiler available to verify that `sync` reproduces the tracked files.

```sh
go tool leanfran sync
git diff --exit-code
```

Add the following directive to a Go file so `go generate ./...` runs `sync`.

```go
//go:generate go tool leanfran sync
```

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

## Verify a Go function in Lean

Attach a `//leanfran:model` directive to a Go function. Put the specification in an embedded Lean block. This example checks a nibble mask against a remainder operation.

```go
var _ = leanfran.Lean(`
def nibbleSpec (x : UInt8) : UInt8 := x % 16
def inRange (_x r : UInt8) : Bool := decide (r < 16)
`)

//leanfran:model refines=nibbleSpec ensures=in_range:inRange
func Nibble(x uint8) uint8 { return x & 15 }
```

| Directive option | Meaning |
| --- | --- |
| `refines=name` | A Lean function with the same arguments that returns the expected result. |
| `requires=name` | A Lean function with the same arguments that returns `Bool`. Every obligation assumes it returns `true`. |
| `ensures=label:name[,label:name…]` | Lean functions returning `Bool` that take the original arguments followed by the result. Use a distinct label for each postcondition. The label `refines` is reserved. |
| `spec=import/path` | The package that contains the block. The modeled function's package is the default. |

Specify at least one refinement or postcondition. Use Lean names relative to the block, with dots for nested namespaces. The named specifications also need public Go wrappers for the generated property tests.

### Obligations and proof status

Find the generated module `LeanGoModel.B<hex>` under `.leanfran/workspace/verification` after running `go tool leanfran check`. The suffix is the Go package import path encoded as hexadecimal UTF-8 bytes. Write the proofs in `lean/Proofs/` beside `go.mod` and import that module. Each obligation is an abbreviation such as `Nibble.obligation.refines`. Prove it with a declaration named `Nibble.proof.refines` in the model's namespace. The [nibble proof](../langs/Go/samples/verified-nibble/lean/Proofs/Nibble.lean) establishes the equality and range bound for every input. The [clamp proof](../langs/Go/samples/verified-clamp/lean/Proofs/Clamp.lean) compares early returns with nested Lean `min` and `max` under an ordered-bounds precondition.

A refinement compares the translated return value with the specification for every input that satisfies `requires`. Where the model can fail, refinement requires `Except.ok` with the specified value. A postcondition for a fallible function constrains every successful return. General `for` loops use a partial fixed point. A diverging loop has no successful logical result.

```sh
go tool leanfran check --require proved
go test ./...
go tool leanfran status
```

`check` runs `sync`, type-checks Go with the generated files present, builds the translated models and proof modules, and writes `leanfran.lock` in the Go module root. It reports each obligation's state.

| State | Meaning |
| --- | --- |
| `proved` | The declaration has the expected type and depends only on `propext`, `Quot.sound`, and `Classical.choice`. |
| `sorry` | The declaration depends on `sorryAx`. |
| `axioms` | The declaration depends on an axiom outside the allowed set. This includes tactics that add a native-computation axiom. |
| `missing` | The expected proof declaration is absent. |
| `mismatch` | The declaration's type differs from the obligation. |
| `failed` | A proof file declaring the expected proof fails to build. |
| `unextracted` | The translator or Lean could not produce the obligation. Diagnostics include a Go source location. |
| `stale` | `status` needs a fresh lock after a change to the Go sources, specs, proofs, configuration, or model library. |

`check --require proved` exits with an error if any obligation has a state other than `proved`. Ordinary `check` exits with an error when extraction or a requested proof build fails. `status` reads the saved state and checks freshness with Go alone.

### Go subset and proof scope

The translator accepts top-level, non-generic functions with ASCII names and local state. It uses fixed-width Lean integers, `Bool`, `String`, `Float`, and `Array` for slices. On 64-bit targets `int` and `uint` map to `Int64` and `UInt64`. Named strings use `String` unless they represent a Lean-generated enum. Supported structs have direct fields and a matching type in an embedded block. Untagged Go structs can be made available to the block with `Models`. For a Lean-generated type with validation constraints, use values that satisfy the generated validator. The translated signatures assume only the invariants of supported generated types. Tags on hand-written Go structs supply no proof assumptions. When a supported `Models` struct has tagged fields, use the block's `GoValues.<Name>` type in specs. Its Go wrapper accepts the original Go struct, and its Lean representation contains just the field values.

Supported statements include local declaration and assignment, parallel assignment, increment and decrement, `+=`, `-=`, `*=`, `if`, early returns, expression `switch`, `for` and integer or slice `range`. Slice writes and appends require a uniquely owned local slice of scalar elements. A return from `(T, error)` can use `nil`, `errors.New`, or `fmt.Errorf` with a single constant message. An error-returning model call can be forwarded in a direct return. Calls between models must be statically resolved and acyclic.

Expressions cover fixed-width arithmetic, unsigned bitwise operators, comparisons, short-circuit booleans, `len`, `min`, `max`, integer conversions, string concatenation, indexing, field reads, and supported slice and struct literals. Integer division truncates toward zero. Division by zero, indexing outside a slice, negative shift counts, and `panic` produce modeled failures. Shifts by the integer width or more return zero. Strings must contain valid UTF-8, and `len` counts bytes. The slice model treats a nil slice as empty.

Keep pointers, maps, channels, goroutines, I/O, globals, closures, methods, generics, `defer`, `recover`, slice expressions, string ranges, and writes through slice aliases outside modeled functions. Other unsupported forms include named error results, keyed slice literals, and cases that combine a switch break with a continue to an enclosing loop. Flattened generated structs and constructors requiring proofs need a spec over a supported value representation.

The trusted pieces outside each proof are the Go translator, [the operation model](../langs/Go/lean/LeanGoLib/Go.lean), the leanfran Go generator and runtime, the Go compiler, and the valid UTF-8 input contract. Translation tests compare handwritten Go with the generated model via Lean's C backend. Operation tests compare code generated from the Lean operation model with native Go, including boundary values and the correspondence between modeled failures and Go panics. These tests include valid multibyte strings and byte lengths. Property tests exercise the generated spec wrappers, the Go toolchain, and the user's implementation together on valid inputs.

### Property tests

`sync` generates `leanfran_model_test.go` in each modeled Go package. Commit it alongside the embedded Go outputs and the lock. The generated `TestLeanfranModels` calls `leanfrantest.Check(t, model)`. It uses boundary values and seeded random values, discards inputs rejected by the precondition, and reports the seed and input when the implementation and spec disagree. Errors and panics from the implementation also fail the test on an accepted input. The defaults are 200 accepted inputs and seed 1. For manual tests, supply options `leanfrantest.Runs(n)` and `leanfrantest.Seed(seed)`. These tests use the generated Go specifications and run with Go alone.

## Generating from a compiled Lean module

Install the compiler as described above. Use the same Lean toolchain as the compiler to produce the `.olean` files. Place Go and `gofmt` on your PATH and add `github.com/conao3/leanfran-go` to your Go module.

```sh
lean -o Pricing.olean Pricing.lean
leanfran-go module generate --module-name Pricing --search-path . \
  --output-dir pricing
```

The command writes `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, and `leanfran_lean_gen.go`. The package name defaults to the last component of the Lean module name in lowercase. Use `--package` to override it. By default, the compiler removes the Lean module name from the start of a public name when it matches the declaration's namespace. For example, `Pricing.total` in the `Pricing` module becomes `pricing.Total`. Use `--namespace` to choose a different prefix to remove and `--roots` to select public functions explicitly.

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

Call a generated value's `JSONSchema(target)` method with `draft-2020-12`, `draft-07`, or `openapi-3.0`. Some proof constraints appear as numeric or length bounds. Call `Validate` to evaluate arbitrary decidable invariants. `LeanfranDesc()` returns the shared type descriptor for read-only use.

## Skipped definitions

The public generator accepts concrete data types and monomorphic functions. The summary identifies indexed families, type classes, propositions, private declarations, constructors with type fields, and propositions without a synthesizable `Decidable` instance. The public layer also skips function-valued types and types from the `Std`, `Lean`, `IO`, and `System` namespaces, along with `Thunk` and `Task`. Public functions can return `IO` results.
