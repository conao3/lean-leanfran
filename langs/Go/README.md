# leanfran for Go

Embed Lean definitions and proofs in a Go package. `go tool leanfran sync` checks the Lean and generates Go functions and types in the same package.

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

With Go 1.26 or later, Lean, Lake, and `leanfran-go` available, run the following from the application module.

```sh
go get -tool github.com/conao3/leanfran-go/cmd/leanfran
go tool leanfran sync
```

Go callers can now use `arithmetic.Twice(big.NewInt(21))`. Commit the generated Go and manifest so the application can build with Go alone.

## Verify a Go function

Add `//leanfran:model refines=nibbleSpec ensures=in_range:inRange` to a top-level Go function. Define the executable specifications in a Lean block and prove the generated obligations under `lean/Proofs/`.

```sh
go tool leanfran check --require proved
go test ./...
```

The [nibble sample](samples/verified-nibble/) checks a bit mask against a remainder, and the [clamp sample](samples/verified-clamp/) checks a clamp against an independently written specification. See [Verify a Go function in Lean](../../docs/go-guide.md#verify-a-go-function-in-lean) for the directive, proof states, and supported Go syntax.

Build the compiler with `nix build .#go` from the repository root. The [range sample](samples/embed-range/) includes a Lean structure, a theorem, and a Go caller. The [Go guide](../../docs/go-guide.md) covers configuration, importing Go models, generated packages, and JSON Schema. See [Go development](../../docs/go-development.md) for building and testing the backend.
