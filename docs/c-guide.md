# C guide

`leanfran-c` generates a C11 API for definitions in a Lean 4.35.0 Lake library. The generated header also works with C++.

## Set up the compiler

From the leanfran repository root, run `nix build .#c` and add `result/bin` to your PATH. To build with elan, run `lake build leanfran-c` in `langs/C` and add its `.lake/build/bin` to your PATH. Use Lean 4.35.0 and a C compiler in the consuming workspace. The linking examples use pkg-config, GNU Make, or CMake.

## Generate and build

In a Lake workspace with a library that contains `Pricing/Core.lean`, define a function to call from C.

```lean
namespace Pricing

def total (quantity unitPrice : UInt64) : UInt64 :=
  quantity * unitPrice

end Pricing
```

From that workspace, generate and build the bindings.

```sh
lake env leanfran-c generate --module-name Pricing.Core --roots Pricing.total \
  --prefix pricing --out-dir out
lake env leanfran-c build --out-dir out
```

Pass a comma-separated list of fully qualified declarations to `--roots`. Omit it to select supported public definitions declared in the module. The default prefix is the last component of the module name in snake case, such as `core` for `Pricing.Core`. Use the same output directory for generation and build.

Save this consumer as `main.c` in the Lake workspace.

```c
#include <inttypes.h>
#include <stdio.h>
#include "pricing.h"

int main(void) {
    lf_error error = {0};
    uint64_t total;
    if (pricing_init(&error) != LF_OK ||
        pricing_total(3, 1200, &total, &error) != LF_OK) {
        fprintf(stderr, "%s\n", error.message ? error.message : "Lean call failed");
        lf_error_clear(&error);
        return 1;
    }
    printf("%" PRIu64 "\n", total);
    return 0;
}
```

```sh
cc -std=c11 main.c $(pkg-config --cflags --libs out/pricing.pc) -o pricing-demo
./pricing-demo
```

The program prints `3600`.

## Call the generated API

Call `<prefix>_init` before using the exported functions. Initialization runs once per generated module, and callers may invoke its initializer concurrently. Each wrapper returns an `lf_status` and writes its result through the output pointer on success. An `IO Unit` wrapper takes no output pointer, and failed Lean I/O returns `LF_IO`.

Initialize each `lf_error` with `{0}` and call `lf_error_clear` to release its message before reusing it. Pass `NULL` when you only need the status code. The C ABI supports booleans, fixed-width integers, `USize`, floating-point numbers, Unicode scalar values, UTF-8 strings, and `IO` results. An input `lf_str` borrows a byte buffer of length `len`. A returned `lf_str` owns its buffer, which may contain embedded NUL bytes and has a trailing NUL beyond `len`. Release the returned `ptr` with `lf_free`.

## Generation checks

- If a selected definition depends on `sorryAx`, generation reports the declaration and exits with status 254. `--allow-sorry` turns this check into a warning.
- If the module imports the Lean compiler directly or indirectly, generation reports the import chain and exits with status 254. `--allow-lean-import` enables the compiler dependency in the generated link configuration.
- Supply the C symbols listed in `<prefix>.externs.txt` when linking the consumer. An extern for another backend, such as `go:foreign.Increment`, is rejected during generation. `<prefix>.implemented-by.txt` lists Lean declarations that call a replacement implementation.

## Link the library

The default build produces `lib<prefix>.a`. Use `leanfran-c build --shared --out-dir out` for `lib<prefix>.so` on Linux or `lib<prefix>.dylib` on macOS, linked with `libleanshared`. The build also writes link settings for all three build tools.

- **pkg-config** accepts `out/pricing.pc` in the command above. For a path containing spaces, get the flags through your build system so it can preserve argument boundaries.
- **GNU Make** can include `out/pricing.mk`. Compile with `$(PRICING_CFLAGS)` and put `$(PRICING_LDLIBS)` after the source or object arguments.
- **CMake** can use `find_package(pricing CONFIG REQUIRED)` and `target_link_libraries(pricing-demo PRIVATE pricing::pricing)`. Set `-Dpricing_DIR=/absolute/path/to/out` when configuring.

The generated settings use absolute paths to the output directory and the active Lean toolchain. Run generation and build again if either moves. Keep the shared library and its Lean runtime dependencies available at the recorded paths when running a dynamically linked executable.

### GMP when distributing binaries

Inspect `leanc --print-ldflags` and the generated link settings to see which GMP your build uses. The Linux Lean distribution installed by elan can link GMP statically. To link against shared GMP, use the project's Nix Lean environment with `nix develop .#c` and regenerate and build the bindings with that toolchain.

GMP is available under LGPLv3 or GPLv2. If you distribute a statically linked executable under the LGPLv3 terms for GMP, see section 4 for notices, license texts, and the materials and terms that let recipients relink the executable with a modified GMP. The section also describes the shared-library option. [GMP licensing](https://gmplib.org/#WHAT) and [LGPLv3 section 4](https://www.gnu.org/licenses/lgpl-3.0.html#section4).
