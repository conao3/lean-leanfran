# leanfran-c

Generate a C API for Lean 4 definitions in a Lake workspace. The C compiler links the generated static archive with Lean's runtime.

Build the tool with `lake build` in this directory, or with `nix build .#c` at the repository root. Put the resulting `leanfran-c` on your PATH and run the following commands from the Lake workspace that contains your Lean code.

```sh
leanfran-c generate --module-name Pricing.Core --roots Pricing.total --out-dir out
leanfran-c build --out-dir out
leanc -Iout main.c out/libcore.a -o main
```

Run the generator and build commands through `lake env` when your Lake installation supplies custom compiler or archiver settings.

The module must belong to a Lake library. With no `--roots`, the generator selects supported public definitions declared by the module. Pass a comma-separated list of fully qualified names to select specific definitions. The C prefix defaults to the last component of the module name in snake case. Use `--prefix` to set it explicitly.

Include `core.h` and call `core_init` before calling any generated function. The [C guide](../../docs/c-guide.md) describes the public type mappings, naming, and ownership rules. An `IO Unit` function takes no output pointer. String arguments are borrowed UTF-8 byte ranges. String results can contain zero bytes and include a trailing NUL after the reported length. Release the result's `ptr` with `lf_free`.

Start each `lf_error` with `{0}` and release its message with `lf_error_clear`. Pass `NULL` to receive only the status code. Initialization may be called repeatedly or concurrently.

Run the C checks from the repository root with `make check BACKENDS=C`.
