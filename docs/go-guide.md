# Using leanfran from Go

## Embedded Lean

Nix can install the `leanfran` compiler from any directory.

```sh
nix profile install 'github:conao3/lean-leanfran#leanfran'
```

Add `lean`, `lake`, and the `leanfran` compiler to your PATH. Use Lean and Lake from Lean 4.35.0 and match the compiler's release to the Go module version. To pin a release, use `github:conao3/lean-leanfran/<tag>#leanfran` and add the same tag as a version suffix to `go get -tool`.

Use Go 1.26 or later. In your Go module, install the tool and add a top-level block to a Go file.

```sh
go get -tool github.com/conao3/leanfran-go/cmd/leanfran-go
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

Run `leanfran --lang go sync`. The Go package can now call `NewRange(big.NewInt(2), big.NewInt(5))` and `Width(r)`, which returns 3. See the [range sample](../langs/Go/samples/embed-range/) for the full call.

Each package has one block, identified by its Go import path. Use a raw or interpreted string literal with `Lean`, or place the source in the same package directory and pass its filename to `LeanFile`. `Imports("Std.Data.HashMap")` imports a Lean module. `Uses("example.com/app/orders")` opens another block's Lean namespace and shares the Go types generated for it. Pass the options after the source. The options return `leanfran.BlockOption`.

### Use the compiler from a flake

Add leanfran as a flake input and include the `leanfran` compiler in your development shell. Set `system` to `aarch64-darwin` on Apple Silicon.

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
        packages = [ pkgs.go pkgs.lean4 inputs.leanfran.packages.${system}.leanfran ];
      };
    };
}
```

Run `nix develop` from the application's flake directory. Pin `leanfran.url` to the same release tag as the Go module for reproducible compiler and tool versions.

### Commands and configuration

| Command | Effect |
| --- | --- |
| `leanfran --lang go sync` | Scans the module, builds the Lean sources in `.leanfran/workspace`, and installs all generated packages after the build and generation succeed. |
| `leanfran --lang go status` | Checks freshness without Lean or Lake. Reports stale or removed blocks and missing generated files, with exit status 1 when work is needed. |
| `leanfran --lang go check` | Runs `sync` and verifies the result with `status`. |

Run all three commands from the Go module where you registered the tool. They accept `--dir` to choose a directory within that module. The CLI reads the module from that directory and scans its packages.

The compiler runs the project's `leanfran-go` tool through `go tool` and passes its own path in `LEANFRAN_CLI`. The tool uses that path for generation and looks up `leanfran` on PATH when the variable is unset. The compiler must match the Go module release and the tool's generator version. The compiler, `lean`, and `lake` must all match the module's `lean-toolchain`. The default is `leanprover/lean4:v4.35.0`. Use `--verbose` on `sync` or `check` to include Lake trace lines in build diagnostics.

An optional `leanfran.config.json` at the module root takes a `paths` array of directories to scan and a `require` array of Lake dependencies. Dependency entries use the keys of Lake's `[[require]]` entries. Relative dependency paths start at the Go module root.

```json
{
  "paths": ["pricing", "orders"],
  "require": [{"name": "Domain", "path": "../domain"}]
}
```

Commit each block's `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, `leanfran_lean_gen.go`, and `leanfran.json`. Ignore the module's `.leanfran/` directory. The application builds with the Go toolchain. Lean diagnostics point to the original Go literal or Lean file. When a build or proof fails, the previous generated files remain in place.

### Check generated files in CI

The freshness check for committed files requires Go and the `leanfran` compiler.

```sh
leanfran --lang go status
```

Use a clean checkout with Lean, Lake, and the compiler available to verify that `sync` reproduces the tracked files.

```sh
leanfran --lang go sync
git diff --exit-code
```

Add the following directive to a Go file so `go generate ./...` runs `sync`.

```go
//go:generate leanfran --lang go sync
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

Find the generated module `LeanGoModel.B<hex>` under `.leanfran/workspace/verification` after running `leanfran --lang go check`. The suffix is the Go package import path encoded as hexadecimal UTF-8 bytes. Write the proofs in `lean/Proofs/` beside `go.mod` and import that module. Each obligation is an abbreviation such as `Nibble.obligation.refines`. Prove it with a declaration named `Nibble.proof.refines` in the model's namespace. The [nibble proof](../langs/Go/samples/verified-nibble/lean/Proofs/Nibble.lean) establishes the equality and range bound for every input. The [clamp proof](../langs/Go/samples/verified-clamp/lean/Proofs/Clamp.lean) compares early returns with nested Lean `min` and `max` under an ordered-bounds precondition.

A refinement compares the translated return value with the specification for every input that satisfies `requires`. Where the model can fail, refinement requires `Except.ok` with the specified value. A postcondition for a fallible function constrains every successful return. General `for` loops use a partial fixed point. A diverging loop has no successful logical result.

```sh
leanfran --lang go check --require proved
go test ./...
leanfran --lang go status
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

`sync` generates `leanfran_model_test.go` in each modeled Go package. Commit it alongside the embedded Go outputs and the lock. The generated `TestLeanfranModels` calls `leanfrantest.Check(t, model)`. It uses boundary values and seeded random values, discards inputs rejected by the precondition, and reports the seed and input when the implementation and spec disagree. Errors and panics from the implementation also fail the test on an accepted input. The defaults are 200 accepted inputs and seed 1. For manual tests, supply options `leanfrantest.Runs(n)` and `leanfrantest.Seed(seed)`. The sampler uses the generated enum constructors as inputs by decoding their JSON names. These tests use the generated Go specifications and run with Go alone. They accept specification wrappers with either a direct result or a trailing error, depending on the Lean signature.

## Generating from a compiled Lean module

Install the compiler as described above. Use the same Lean toolchain as the compiler to produce the `.olean` files. Place Go and `gofmt` on your PATH and add `github.com/conao3/leanfran-go` to your Go module.

```sh
lean -o Pricing.olean Pricing.lean
leanfran --lang go module generate --module-name Pricing --search-path . \
  --output-dir pricing
```

The command writes `leanfran_types_gen.go`, `leanfran_funcs_gen.go`, and `leanfran_lean_gen.go`. The package name defaults to the last component of the Lean module name in lowercase. Use `--package` to override it. By default, the compiler removes the Lean module name from the start of a public name when it matches the declaration's namespace. For example, `Pricing.total` in the `Pricing` module becomes `pricing.Total`. Use `--namespace` to choose a different prefix to remove and `--roots` to select public functions explicitly.

The JSON summary reports the files and the qualified Lean name and reason for each skipped declaration. Use `--output text` for a human-readable summary. Each generation replaces the output files and removes obsolete Go files with the `Code generated by leanfran-go` header from the output directory. To compile a runtime-facing package or a command, use `--internal-only --output-file` and add `--main` for commands.

## Public types and functions

Structures and inductive types with a single constructor are Go structs with exported fields. Structure fields inherited from a parent appear directly on the child. Inductive types with multiple constructors and payloads have a sealed interface and one struct per constructor. Proof fields become validation checks. Named subtypes have a `Val` field and anonymous subtypes use their base Go type.

Generated enums have a comparable struct type with a private field. Create a value with a constructor function such as `ColorRed()`. The Go zero value selects the first Lean constructor. Use constructor calls in a `switch`, and use `json.Unmarshal` to parse constructor names from JSON. An enum imported through `Models` uses the original Go type and its values.

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

Use Go literals or `New<Type>` for types with invariants. Constructors, `Validate`, JSON decoding, and generated functions check Lean invariants and constraints such as nonnegative naturals, valid UTF-8, and Unicode scalar values. A generated function returns an `error` if it takes a Go input that requires validation or if its Lean result is `IO` or a top-level `Except`. Inputs that require validation include `Nat`, `Int`, `Fin`, `String`, `Char`, subtypes, types with proof fields, and sealed interfaces. Containers and records require validation when their members do. Fixed-width numbers, booleans, byte arrays, unit values, and generated enums can be passed directly. A function with no possible error returns just its result. A `Unit` result contributes no Go return value. Use `errors.As` to inspect `*leanfran.ValidationError`, `*leanfran.ExceptError[E]`, and `*leanfran.IOError`. A validation error contains issues with a message and path for each failing field or parameter. Lean runtime failures such as unreachable IR propagate as `*rt.InternalPanic`.

```go
d, err := pricing.NewDiscountPercent(big.NewInt(10))
if err != nil {
    return err
}
total, err := pricing.Total([]*big.Int{big.NewInt(1200), big.NewInt(800)}, d)
```

Generated functions can run concurrently. Each call copies input data into Lean's runtime representation and copies the result back into Go. During a call, synchronize any mutations of data shared with the call.

To reuse public types from a generated library, use `--type-module Library.Namespace=example.com/myapp/library` when generating the consumer. Generate both packages using the Lean namespace on the left as the library's naming prefix. The consumer imports the library's Go types and conversion functions.

## Keep Lean values with `Value[T]`

Use the ordinary wrappers for Go data such as input from JSON. Use handles when Go keeps a Lean value across calls, such as a server's snapshot. A `leanfran.Value[T]` owns one Lean reference. The generated `Value.NewT` converts Go data once and returns an `error` when T requires input validation. `Value.ReadT` copies the contents back to Go.

For a generated function `F`, `Handle.F` accepts `leanfran.ValueInput[T]` for each argument. Pass `v.Borrow()` to keep using `v` or `v.Take()` to transfer its reference at the start of the call. If the Lean function can update an exclusively owned object in place, `Take` lets it do so. Copies of a Go handle refer to the same owner. Taking it empties every copy. `v.Close()` releases the reference and can be called on an empty handle. Reading or passing an empty handle panics. A handle that becomes unreachable before `Close` or `Take` never returns its Lean reference. Go's garbage collector reclaims the Lean objects that only that handle reached, so their memory is not lost. Objects it shares with live handles keep a reference count above one, so later calls copy them instead of updating them in place. A forgotten `Close` therefore shows up only as slower updates, not as an error. In a test, call `region.TrackLeakedValues(true)` on the region it uses. Then `region.CollectLeakedValues()` runs garbage collections until the region's tracked handles stop being finalized and returns the number collected while holding a reference. Tracking one region leaves parallel tests in other regions unaffected. `leanfran.TrackLeakedValues(true)` and `leanfran.CollectLeakedValues()` do the same for every handle in the process. A tracked handle takes its own allocation instead of a slot in the scope.

Handle functions return an `error` only for `IO` or a top-level `Except`. A `Unit` result contributes no handle. A top-level product returns two handles. For an `Except E (A × B)`, the two handles hold the successful product fields. Use `errors.AsType[*leanfran.ExceptError[E]](err)` when the error has a Go representation, or `*leanfran.ExceptError[leanfran.Value[E]]` for an opaque Lean error. Unlike `errors.As`, `errors.AsType` does not allocate a target on every call. Use `leanfran.SplitValue` on a product already held in a handle. The JSON summary's `valueFunctions` map gives package-relative selectors such as `Handle.Width`. Each `valueConversions` entry lists the type stem and its `new`, `read`, `newIn`, and `readIn` selectors.

Generated packages reserve `Handle` and `Value` for these method sets. A Lean name that maps to `Handle` or `Value` receives one leading `Lean`, as do names with existing `Lean` prefixes before either reserved word. For example, the Lean type `Value` is exported as `LeanValue`. A function named `in` has the handle method `Handle.LeanIn`, with the same rule for existing `Lean` prefixes before `In`. Ordinary wrappers keep their own package-level identifiers.

Named Lean data types use their generated Go type as the handle parameter. Built-in type markers distinguish types with a shared Go representation, such as `leanfran.NatType` and `leanfran.IntType`, or `leanfran.ListType[T]` and `leanfran.ArrayType[T]`. Types with decidable proof fields use the existing validated Go conversion. Types with proofs that Go cannot validate and types containing `Std.HashMap` get opaque type markers. Construct and inspect those values through Lean functions that take and return handles.

Use one server mutex around a sequence that reads, updates, and replaces its snapshot. Handle operations in one region run one at a time, because the handles of a region can share Lean subobjects. Goroutines can move between OS threads. Here the snapshot is borrowed during `Handle.Transition` so the server can keep it if Lean returns an error. [Inventory server example](../langs/Go/samples/value-server/main.go).

```go
s.mu.Lock()
defer s.mu.Unlock()
next, reply, err := inventory.Handle.Transition(s.snapshot.Borrow(), command.Take())
if err != nil {
    return 0, err
}
defer reply.Close()
s.snapshot.Close()
s.snapshot = next
return inventory.Value.ReadUInt64(reply), nil
```

Call `v.IsExclusive()` to check whether the Lean heap object has one reference at that moment. Scalars and persistent objects return false. Go copies of the same handle share one owner, and child objects have their own reference counts. To check a handle and consume it under the same lock, use `v.IsExclusiveIn(scope)` inside `WithValues`.

### Run handles in parallel with regions

A `*leanfran.Region` holds one mutex. Every handle belongs to at most one region, which `v.Region()` returns. Operations on the handles of one region run one at a time, and operations in separate regions run in parallel. Give each independent snapshot, such as one tenant's state, its own region from `leanfran.NewRegion()`.

- A handle created in a scope, and every result of a call in a scope, belongs to the scope's region.
- A call outside a scope runs in the region of its input handles. If no input belongs to a region, the call runs in the default region.
- A call outside a scope without handle inputs, such as `Handle.Init()`, takes no mutex. Its result belongs to no region, because it refers only to new objects and persistent constants. A call that returns two handles puts both in the default region.
- To create a handle in a region from the start, call `Value.In(scope).NewT` inside the region's `WithValues`.
- A handle that `Value.NewT` creates outside a scope, or that a call without handle inputs returns, belongs to no region until its first operation. It then joins that operation's region and stays there. `ReadT`, `Close`, `IsExclusive`, and passing it with `Borrow` or `Take` count as operations. If calls in two regions take the same such handle at the same time, one call gets it and the other panics with the message below.
- A call whose inputs belong to two regions panics with `leanfran: Values from different Regions in one call`, before it takes any reference. Passing another region's handle to a call in a scope panics the same way. To move data between regions, read it with `Value.ReadT` and create it again in the other region.
- Constants and other persistent Lean values are never written, so every region can use them.

Programs that never create a region keep all their handles in the default region, and their handle operations run one at a time.

`r.WithValues` holds the region's mutex across a callback, and `leanfran.WithValues` does the same for the default region. Call `Handle.In(scope)` and `Value.In(scope)` to use the same methods with its `*leanfran.ValueScope`. Also pass the scope to `v.CloseIn` and `leanfran.SplitValueIn`. Use scoped calls throughout the callback. Call a region's `WithValues` from outside its active callbacks, and do not call handles of the scope's region without the scope inside a callback, because the mutex is already held. A call without the scope whose inputs belong to no region runs in the default region and puts its result there, so a later call in the callback's region panics. The scope expires on return. Handles can outlive the scope and use ordinary calls again. A scope stores its first eight handles in its own allocation, so a callback that creates up to eight handles allocates once for all of them. The JSON summary's `scopedValueFunctions` map gives call templates such as `Handle.In(scope).Width`.

```go
type tenant struct {
    region   *leanfran.Region
    snapshot leanfran.Value[inventory.Snapshot]
}

func (t *tenant) reserve(amount uint64) (uint64, error) {
    var result uint64
    var err error
    t.region.WithValues(func(scope *leanfran.ValueScope) {
        command := inventory.Value.In(scope).NewUInt64(amount)
        next, reply, callErr := inventory.Handle.In(scope).Transition(t.snapshot.Borrow(), command.Take())
        if callErr != nil {
            err = callErr
            return
        }
        defer reply.CloseIn(scope)
        result = inventory.Value.In(scope).ReadUInt64(reply)
        t.snapshot.CloseIn(scope)
        t.snapshot = next
    })
    return result, err
}
```

The region's mutex also serializes the callbacks of one tenant, so `t.snapshot` needs no other lock. Create the first snapshot in the region with `t.region.WithValues` and `Handle.In(scope)`.

The kernel fixture measures `transition`, `apply`, and reading the reply in Go. For handle measurements, it prepares the actor and command outside the timed loop and hands the snapshot to `apply` with `Take`. The final-row benchmark selects the last row on every call.

On Linux amd64 with an Intel Core i5-8400 and Go 1.27.3, the median of five runs on one CPU, with a load average of 3 to 11 from other work on the six cores, was:

| Snapshot rows | Ordinary wrappers, first row | Handles, first row | Handles, final row | Scoped handles, final row |
| ---: | ---: | ---: | ---: | ---: |
| 1 | | | 0.69 µs, 6 allocs | 0.70 µs, 5 allocs |
| 10 | 5.68 µs, 71 allocs | 0.75 µs, 6 allocs | | |
| 100 | 58.36 µs, 575 allocs | 0.83 µs, 6 allocs | 2.97 µs, 6 allocs | 2.89 µs, 5 allocs |
| 1,000 | 563.96 µs, 5,534 allocs | 0.78 µs, 6 allocs | 25.72 µs, 6 allocs | 33.56 µs, 5 allocs |
| 10,000 | | | 0.53 ms, 6 allocs | 0.39 ms, 5 allocs |

At 100 rows, the first-row handle benchmark took 0.73 µs with 6 allocations under the server mutex. Converting a Go command each time took 0.91 µs with 8 allocations. Finding a missing row walks the whole list in 3.1 ns per row at 1,000 rows and 4.6 ns per row at 10,000 rows without allocating. A handle command allocates 272 bytes, and a scoped command with Go conversions allocates 496 bytes.

Passing an array by value converts every element on the way in and on the way out. The kernel fixture's `record (values : Array UInt64) (value : UInt64) := values.push value` generates `Record(values []uint64, value uint64) []uint64`. `doubled` pushes each doubled element into an array created with the input's size. `Handle.ReplaceLast` takes the array handle, replaces its last element in place, and returns it. On the same machine with a load average of 1.2 to 1.9, the median of five runs on one CPU was:

| Elements | `Record`, slice in and out | `Doubled`, slice in and out | `Handle.ReplaceLast` with `Take` |
| ---: | ---: | ---: | ---: |
| 10 | 0.40 µs, 4 allocs, 608 B | 0.49 µs, 5 allocs, 464 B | 73 ns, 1 alloc, 24 B |
| 1,000 | 15.6 µs, 4 allocs, 49,184 B | 18.9 µs, 5 allocs, 41,025 B | 74 ns, 1 alloc, 24 B |
| 100,000 | 1.98 ms, 4 allocs, 4,415,520 B | 2.34 ms, 6 allocs, 4,014,279 B | 77 ns, 1 alloc, 24 B |

Generated Lean code calls the runtime through one-line wrappers such as `l_Array_push` and `l_String_getUTF8Byte`. Go inlines a function whose cost is at most 80, so each wrapper of a small runtime function inlines, and a byte read or a push costs no extra call. lean-leangage's token parser, JSON writer and notes list, which build `Array UInt8` values from strings, ran 4 to 9% fewer instructions per call with the wrappers inlined, at 196,000 token checks, 261,000 splits, 1.23 million calculator replies and 5,550 notes lists of 20 per second on the machine above.

`make test-array-cost` times `Record` and the Lean loop of `doubled` with 1,000 elements against Go code that allocates the same slices, and `BytesOf`, which copies a 1,000-byte string into an `Array UInt8` with `String.getUTF8Byte` and `Array.push`. It runs on one P, so the cost of the garbage collector's write barriers shows, and it takes the median of nine rounds. `Record` and the Lean loop must stay within 2.5 times their Go controls and `BytesOf` within 4.6 times. On the machine above they took 1.6, 1.8 and 3.3 times. Set `LEANFRAN_ARRAY_COST_SCALE` to multiply the limits. The same target builds the generated kernel with `-gcflags=-m=2` and fails if a generated function whose body is one call of an `rt` function does not inline, naming the function and its cost.

`make test-value-regions` runs a scoped command with Go conversions on a one-row snapshot. On the Linux amd64 CI runner (4 CPUs, Go 1.27.3), one goroutine in one region completed 2.0 to 2.1 million commands per second, and eight goroutines in eight regions completed 3.3 to 3.9 million, 1.7 to 2.0 times as many. The same Lean functions without a handle lock scaled by 1.6 to 1.9 times, so allocation and garbage collection, not the region mutex, bound the speedup.

## JSON and JSON Schema

Generated types implement `json.Marshaler`. Use `json.Unmarshal` for structs, enums, and a known constructor. For an interface, use `Unmarshal<Type>(data)` to select the constructor from JSON.

Lean JSON conventions include decimal strings for `UInt64` and `USize`, numbers for unbounded integers, arrays for products and bytes, and externally tagged objects such as `{"percent":{"p":10}}` for constructors with fields. Constructors with no fields are strings. A named structure field such as `note?` is emitted as `note` when present and omitted otherwise. JSON uses `null` for both `none` and `some none` in nested options. The Go representation preserves both cases across calls into Lean.

Call a generated value's `JSONSchema(target)` method with `draft-2020-12`, `draft-07`, or `openapi-3.0`. Some proof constraints appear as numeric or length bounds. Call `Validate` to evaluate arbitrary decidable invariants. `LeanfranDesc()` returns the shared type descriptor for read-only use.

## Skipped definitions

The public generator accepts concrete data types and monomorphic functions. The summary identifies indexed families, type classes, propositions, private declarations, constructors with type fields, and propositions without a synthesizable `Decidable` instance that it skips for Go data conversion. The public layer also skips function-valued types and types from the `Std`, `Lean`, `IO`, and `System` namespaces, along with `Thunk` and `Task`. Public functions can return `IO` results.
