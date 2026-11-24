# Go development

leanfran compiles Lean 4 IR into Go source. The bundled runtime uses the Go standard library and supports 64-bit Linux and macOS. A generated package can be built with `CGO_ENABLED=0`.

## Layout

- `langs/Go/Main.lean` implements the `leanfran-go` CLI. `langs/Go/LeanGo/EmitGo.lean` collects reachable IR, emits Go, and assembles package initialization and command entry points.
- `langs/Go/rt/` implements the runtime. It uses `rt.V` for Lean objects and Go's fixed-width types for unboxed scalars. Arrays and strings use copy-on-write, and tail calls between functions use a trampoline.
- `langs/Go/LeanGo/RuntimeExterns.lean` lists the runtime symbols. The emitter reports missing names before producing output.
- `langs/Go/LeanGoTest/` holds Lean fixtures for native and generated programs. `langs/Go/testdata/` holds Go drivers for generated packages. `langs/Go/test-out/` holds check artifacts.
- `langs/Go/make/` registers check targets through `CHECK_TARGETS`. `maint/Go/` contains the extern generator and the test scripts.

## Conventions

- Use the repository's `lean-toolchain` for compiler builds and native oracles. Check the toolchain's Lean sources and `lean.h` for the symbol, argument order, erased parameters, and ownership of each extern. Increment a retained value read from a container and leave borrowed arguments owned by the caller.
- Extend the differential fixtures when runtime behavior changes. Regenerate the extern inventory with `make gen-externs` and commit it with the runtime change.
- When generated code changes, raise `generatorVersion` in `Main.lean` and `GeneratorVersion` in `leanfran.go` together. Regenerate the sample package in `samples/sum-to/arith/` with the compiler command from `maint/Go/test-samples.sh`.
- A mutable `rt.V` belongs to one goroutine. Generated package initializers mark their shared values persistent before publication. Each caller can construct its own inputs and call generated functions concurrently. Lean tasks run synchronously.
- Use `gofumpt` for handwritten Go and `gofmt` for generated Go. Run static checks and the native comparison in the backend shell.

## Verification

From the repository root, run the checks for Go 1.27 and 1.26 and build the Nix compiler package.

```sh
nix shell nixpkgs#gnumake -c make check BACKENDS=Go
nix build .#go
```

The check compares output, errors, and exit status with Lean's C backend. It exercises the numeric externs, seeded fuzz cases, tail and non-tail recursion, container update complexity, IR constructor coverage, and concurrent calls to a generated package under the Go race detector. It also checks the extern inventory, handwritten and generated code, and both samples.

```sh
nix develop .#go -c make -C langs/Go gen-externs
nix develop .#go126 -c make -C langs/Go fuzz SEED=42 N=2000
nix develop .#go -c make -C langs/Go samples
```

The sum-to sample imports a generated package and calls it from Go. The greet-cli sample compiles a Lean `main` into a Go command and checks the greeting and usage paths. The sample executables are written to `langs/Go/test-out/samples/`.
