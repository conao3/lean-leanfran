# Go development

leanfran compiles Lean 4 IR into Go source. The bundled runtime uses the Go standard library and supports 64-bit Linux and macOS. A generated package can be built with `CGO_ENABLED=0`.

## Layout

- `langs/Go/LeanGo/Cli.lean` implements the `leanfran-go` CLI. `langs/Go/LeanGo/EmitGo.lean` collects reachable IR, emits Go, and assembles package initialization and command entry points.
- `langs/Go/LeanGo/Marshal.lean` inspects Lean signatures and constructor layouts and compiles proof deciders. `Generate.lean` emits public types, typed conversions, descriptors and function wrappers.
- `langs/Go/cmd/leanfran/` implements the module tool. `internal/embed/` scans Go with `go/parser`, reads the selected model types with `go/types`, and builds a Lake workspace for the embedded blocks. The batch generator uses the model's Go import path and fields to emit a codec against the original type.
- `langs/Go/internal/verify/` reads directives and lowers typed Go ASTs into Lean `do` notation. The embedding CLI invokes it after installing the generated Go package. `LeanGo/Check.lean` checks the compiled proof declarations.
- `langs/Go/lean/LeanGoLib/Go.lean` defines modeled failure and Go operations. The tool embeds its source and writes it into the Lake workspace. The Nix compiler package also installs the source in `share/leanfran-go/LeanGoLib/`.
- `langs/Go/leanfrantest/` runs seeded tests against public Lean spec wrappers. It is called by the Go files that `sync` generates in each modeled package.
- `langs/Go/schema/` renders JSON and JSON Schema from generated descriptors. The root Go package provides validation errors and typed conversion combinators.
- `langs/Go/value.go` manages handle ownership and serializes Lean reference counts shared across handle calls. `langs/Go/rt/` implements the runtime. It uses `rt.V` for Lean objects and Go's fixed-width types for unboxed scalars. A constructor object places its fields directly after an 8-byte header, and `Lean_ctor_get` computes a field's address from its index. Other kinds keep a field slice in `objS`, and a kind with a Go payload such as a string or closure uses the larger `objX` allocation. The generated conversions write and read constructor fields with the `rt.Lean_ctor_set*` and `rt.Lean_ctor_get*` functions. Arrays and strings use copy-on-write, and tail calls between functions use a trampoline.
- `langs/Go/LeanGo/RuntimeExterns.lean` lists the runtime symbols. The emitter reports missing names before producing output.
- `langs/Go/LeanGoTest/` holds Lean fixtures for native and generated programs. `langs/Go/testdata/` holds Go drivers for generated packages. `langs/Go/test-out/` holds check artifacts.
- `langs/Go/make/` registers check targets through `CHECK_TARGETS`. `maint/Go/` contains the extern generator and the test scripts.

## Conventions

- Use the repository's `lean-toolchain` for compiler builds and native oracles. Check the toolchain's Lean sources and `lean.h` for the symbol, argument order, erased parameters, and ownership of each extern. Increment a retained value read from a container and leave borrowed arguments owned by the caller.
- Extend the differential fixtures when runtime behavior changes. Regenerate the extern inventory with `make gen-externs` and commit it with the runtime change.
- When generated code changes, raise `generatorVersion` in `LeanGo/Cli.lean` and `GeneratorVersion` in `leanfran.go` together. Regenerate the Go packages in `samples/sum-to/arith/` and `samples/pricing/pricing/` with the compiler commands from `maint/Go/test-samples.sh`. Run `go tool leanfran sync` in each embedded sample module with `LEANFRAN_GO_CLI` pointing to the rebuilt compiler.
- A mutable `rt.V` belongs to one goroutine. Generated package initializers mark their shared values persistent before publication. Each caller can construct its own inputs and call generated functions concurrently. Lean tasks run synchronously.
- Internal runtime errors and unreachable IR raise `*rt.InternalPanic`. A Go caller can recover and call the library again. The generated command entry point handles this panic during initialization and execution, prints its diagnostic, and exits with status 1.
- Use `gofumpt` for handwritten Go and `gofmt` for generated Go. Run static checks and the native comparison in the backend shell.

## Verification

From the repository root, run the checks for Go 1.27 and 1.26 and build the Nix compiler package.

```sh
nix shell nixpkgs#gnumake -c make check BACKENDS=Go
nix build .#go
```

CI runs both Go versions on Linux amd64. On macOS arm64, it runs Go 1.27 and builds the Nix compiler package. To reproduce the macOS checks, run `nix develop .#go -c make -k -C langs/Go check` from the repository root.

The I/O fixture compares relative executable lookup via the child's `PATH` with Lean C on both platforms. Linux also compares the `inheritEnv = false` case with Lean C. On macOS, the Go executable is checked against the expected output and exit status for that case because Lean 4.35's Darwin runtime clears `environ` to null and then calls `setenv`, which segfaults.

The check compares output, errors, and exit status with Lean's C backend. It also compares two independent runs of the compiler on the same input and checks the default package name for a nested Lean module. It exercises the numeric externs, seeded fuzz cases, tail and non-tail recursion, container update complexity, IR constructor coverage, and concurrent calls to a generated package under the Go race detector. It also checks the extern inventory, handwritten and generated code, and the samples. `test-public` compares generated Go with the native C backend and compares JSON Schema with the TypeScript backend for all three targets. It also checks validation, type mapping, cross-package generation, error handling, deterministic output, a million-element list, and the race detector. The public fixture parses declarations from all three generated files to check for underscores in exported names. Staticcheck ST1003 checks the consumer and copies of the public wrapper files with their generated-code headers removed.

```sh
nix develop .#go -c make -C langs/Go gen-externs
nix develop .#go126 -c make -C langs/Go fuzz SEED=42 N=2000
nix develop .#go -c make -C langs/Go samples
```

`test-embed-scan` checks literal scanning, source positions, and block dependencies. `test-embed` installs the CLI as a module tool in a fixture, checks round-trip models and tags, and verifies that failed proofs and syntax errors preserve the installed Go. It checks manifests with a PATH that contains Go alone. `test-embed-samples` rebuilds the two embedded modules, compares their generated files with the checkout, and compares the range sample with a native Lean C oracle.

Run `make test-kernel` in `langs/Go/` to compare 5,000 seeded commands through the ordinary Go functions, the handle functions, and Lean's native C backend. It also checks distinct handle types at compile time, tests shared handles and scoped calls with eight goroutines under the race detector, and checks allocation limits for updates to the first and final rows. Under the race detector, eight goroutines update snapshots in separate regions, two goroutines borrow one snapshot of a region, and calls that mix two regions panic before they take a reference. A command in one region completes while a callback holds another region or the default region, and waits while a callback holds its own region. `make test-value-regions` runs commands in one region on 1 goroutine and in eight regions on 8 goroutines, and runs the same Lean functions without a handle lock on 1 and 8 goroutines. The regions' 8-to-1 ratio must reach 0.6 of the ratio without a lock. Set `LEANFRAN_REGION_SHARE` to change the share. `make test-value-cost` prints the allocation counts of an ordinary command, a final-row command and a scoped command with Go conversions, limits the scoped command to 512 bytes, checks that walking 10,000 rows allocates nothing, and counts a leaked handle with `leanfran.TrackLeakedValues`. `make test-value-misuse` runs under the race detector. In 200 trials, two regions take the same handle that belongs to no region, and exactly one call must panic with the mixed-regions message. It also checks that a call without handle inputs inside a region's callback returns a handle that belongs to no region. `region.CollectLeakedValues` must count the handles leaked in a tracked region and none in an untracked region, in a parallel test. `make test-array-cost` times `Record` with a 1,000-element slice, the Lean loop of `doubled` and `BytesOf` with a 1,000-byte string against Go code that allocates the same, on one P and as the median of nine rounds, and allows three attempts. `Record` and the loop must stay within 2.5 times their controls and `BytesOf` within 4.6 times, with at most 4, 2 and 7 allocations. Set `LEANFRAN_ARRAY_COST_SCALE` to multiply the limits. It also builds the generated kernel with `-gcflags=-m=2` and requires every generated function whose body is one call of an `rt` function to inline. When a runtime change makes such a wrapper exceed Go's inline budget of 80, keep the runtime function's fast path cheap and move its rare path into a function that does not inline. After generation, run the kernel benchmark in the backend shell:

```sh
cd langs/Go
go test ./test-out/_generated/kernel -run '^$' -bench '^Benchmark(Command|LastRowCommand|ScopedLastRowCommand|ScopedCommand|Walk)$' \
  -benchmem -benchtime=300ms -cpu=1 -count=5
```

Run `make test-verify` from `langs/Go/` to check obligation states, proof freshness with Go alone, Go-to-Lean translation against the C backend, and model operations against native Go. `make test-verify-samples` checks both verified samples and demonstrates that changing the nibble mask makes the seeded test fail. `make samples` includes this target.

The sum-to sample imports a generated package and calls it from Go. The greet-cli sample compiles a Lean `main` into a Go command and checks the greeting and usage paths. The pricing sample exercises generated public functions, proof validation and JSON. The value-server sample keeps an inventory snapshot under a mutex and tests a successful reservation, a rejection, and the next successful reservation through an HTTP handler. The sample executables are written to `langs/Go/test-out/samples/`.

## Publishing

The Go Publish job checks that the release tag matches `Version` in `leanfran.go` and `version` in `LeanGo/Cli.lean`. It snapshots the Go module and license at the root of the read-only mirror `conao3/leanfran-go`. The `go-mirror` environment supplies `GO_MIRROR_DEPLOY_KEY` to push `main` and the `vX.Y.Z` tag in one atomic operation. A retry with the same tag succeeds when the snapshot matches the tagged tree. A different tree for the same tag fails.

The job checks that Go resolves the tag directly from the mirror. Consumers can install the [published module](https://pkg.go.dev/github.com/conao3/leanfran-go) with `go get github.com/conao3/leanfran-go@vX.Y.Z`, substituting the published tag. The Lean compiler is available through `nix build .#go` in the source repository. Go major versions from v2 onward require the corresponding `/vN` suffix in the module and import paths.

Run `nix develop .#go -c make -C langs/Go test-publish` to exercise the mirror push locally. The check resolves the tagged module and tool from a bare Git repository, builds and runs the generated range example, verifies its manifest with `go tool leanfran status`, and checks identical and conflicting tag retries.
