# leanfran for Go

Embed Lean definitions and proofs in a Go package. `go tool leanfran sync` checks the Lean and generates Go functions and types in the same package.

Nix can install the compiler from any directory.

```sh
nix profile install 'github:conao3/lean-leanfran#go'
```

```go
package arithmetic

import "github.com/conao3/leanfran-go"

var _ = leanfran.Lean(`
def twice (n : Nat) : Nat := n + n

theorem twice_ge (n : Nat) : n ≤ twice n := by
  unfold twice
  omega
`)
```

With Go 1.26 or later and Lean and Lake from Lean 4.35.0 on your PATH, run the following from the application module.

```sh
go get github.com/conao3/leanfran-go
go get -tool github.com/conao3/leanfran-go/cmd/leanfran
go tool leanfran sync
```

Go callers can use `value, err := arithmetic.Twice(big.NewInt(21))`. The error reports an invalid `Nat` input. Pure functions whose inputs need no validation return their result directly. Commit the generated Go and manifest so the application can build with Go alone.

## Verify a Go function

Add `//leanfran:model refines=nibbleSpec ensures=in_range:inRange` to a top-level Go function. Define the executable specifications in a Lean block and prove the generated obligations under `lean/Proofs/`.

```sh
go tool leanfran check --require proved
go test ./...
```

The [nibble sample](https://github.com/conao3/lean-leanfran/tree/master/langs/Go/samples/verified-nibble) checks a bit mask against a remainder, and the [clamp sample](https://github.com/conao3/lean-leanfran/tree/master/langs/Go/samples/verified-clamp) checks a clamp against an independently written specification. See [Verify a Go function in Lean](https://github.com/conao3/lean-leanfran/blob/master/docs/go-guide.md#verify-a-go-function-in-lean) for the directive, proof states, and supported Go syntax.

The [range sample](https://github.com/conao3/lean-leanfran/tree/master/langs/Go/samples/embed-range) includes a Lean structure, a theorem, and a Go caller. The [Go guide](https://github.com/conao3/lean-leanfran/blob/master/docs/go-guide.md) covers matching the compiler to the Go module, configuration, importing Go models, generated packages, and JSON Schema. See [Go development](https://github.com/conao3/lean-leanfran/blob/master/docs/go-development.md) for building and testing the backend.
