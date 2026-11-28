# leanfran C backend

Generate a C API for Lean 4 definitions in a Lake workspace. Link the generated library with Lean's runtime using pkg-config, Make, or CMake.

Install the compiler with `nix profile install 'github:conao3/lean-leanfran#leanfran'`. To build from a clone, run `lake build leanfran` at the repository root and add `.lake/build/bin` to your PATH. Run the following commands from the Lake workspace that contains your Lean code.

```sh
leanfran --lang c generate --module-name Pricing.Core --roots Pricing.total --out-dir out
leanfran --lang c build --out-dir out
cc main.c $(pkg-config --cflags --libs out/core.pc) -o main
```

Run the generator and build commands through `lake env` when your Lake installation supplies custom compiler or archiver settings.

The module must belong to a Lake library. With no `--roots`, the generator selects supported public definitions declared by the module. Pass a comma-separated list of fully qualified names to select specific definitions. The C prefix defaults to the last component of the module name in snake case. Use `--prefix` to set it explicitly.

Generation rejects exported definitions that depend on `sorryAx` and prints the import chain when the module uses the Lean compiler. Use `--allow-sorry` to turn the first check into a warning and `--allow-lean-import` to link the compiler. See `core.externs.txt` for external C symbols to supply and `core.implemented-by.txt` for Lean declarations that use a different native implementation.

The build writes a static archive by default. Pass `--shared` to build a shared library linked with `libleanshared`. For Make, include `out/core.mk` and use `CORE_CFLAGS` and `CORE_LDLIBS`. For CMake, set `core_DIR` to the output directory, call `find_package(core CONFIG REQUIRED)`, and link against `core::core`. The link files refer to the output directory and the local Lean toolchain. Regenerate them after moving either directory.

Include `core.h` and call `core_init` before calling any generated function. The [C guide](../../docs/c-guide.md) describes the public type mappings, naming, and ownership rules. An `IO Unit` function takes no output pointer. String arguments are borrowed UTF-8 byte ranges. String results can contain zero bytes and include a trailing NUL after the reported length. Release the result's `ptr` with `lf_free`.

Start each `lf_error` with `{0}` and release its message with `lf_error_clear`. Pass `NULL` to receive only the status code. Initialization may be called repeatedly or concurrently.

A C project that is not a Lake workspace can write Lean in block comments of its C sources. `leanfran --lang c sync` builds the blocks into one library, `leanfran --lang c status` reports changed blocks and stale proofs, and `leanfran --lang c check` also translates the C functions marked with `LF_MODEL` to Lean and checks your proofs about the translated definitions. Commit the `leanfran.manifest.json` that `sync` writes and the `leanfran.lock` that `check` writes in the project root. The [proof scope](../../docs/c-guide.md#c-subset-and-proof-scope) lists the calling contract that the proofs assume and what they trust. Projects that use `LF_STRUCT` or `LF_MODEL` need clang on `PATH`, and the commands need `sha256sum` (`shasum` on macOS). See [Embed Lean in C sources](../../docs/c-guide.md#embed-lean-in-c-sources) and [Verify a C function in Lean](../../docs/c-guide.md#verify-a-c-function-in-lean).

Run the C checks from the repository root with `make check BACKENDS=C`.
