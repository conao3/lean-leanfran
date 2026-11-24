# leanfran for Go

Compile Lean functions and types to a Go package. The generated code uses the leanfran runtime and builds without CGo.

Build the compiler from the repository root.

```sh
nix build .#go
```

The [pricing sample](samples/pricing/) has Lean definitions, their generated Go package, and a Go caller. Run it from this directory with Go 1.26 or later.

```sh
go run ./samples/pricing
```

See the [Go guide](../../docs/go-guide.md) for generating a package, calling its functions, and using JSON and JSON Schema. See [Go development](../../docs/go-development.md) for building and testing the backend.
