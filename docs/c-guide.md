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

Initialize each `lf_error` with `{0}` and call `lf_error_clear` to release its message before reusing it. Pass `NULL` when you only need the status code.

## Public types

- Lean scalars use the corresponding C scalar types, including `uint32_t` for `Char` and `size_t` for `USize`. C passes scalar and `lf_str` arguments by value. `lf_str` borrows a UTF-8 byte range on input and owns an allocated, NUL-terminated byte range on output. The length counts bytes, including any embedded zero bytes.
- `Nat` and `Int` use `lf_nat` and `lf_int`. Initialize small values with `lf_nat_from_u64` or `lf_int_from_i64`. Use `_from_dec` to parse a decimal string and `_to_dec` to obtain an owned `lf_str`. `lf_nat_to_u64` and `lf_int_to_i64` return false for values outside their respective ranges.
- Structures use C structs with data fields in declaration order. Each proof field is checked when C supplies the value. `Fin n` uses an alias for `lf_nat`, and `Subtype` uses an alias for the C type of its underlying value.
- A Lean inductive with only nullary constructors uses a C enum. Each enumerator's value is its Lean constructor number. An inductive with payloads uses a struct with a `tag` and an `as` union. The tag selects the active union member. Recursive fields that would make a C value infinitely large use pointers.
- `Option α` uses a struct with `has_value` and `value`. `Array α` and `List α` use a typed `items` pointer and a `len` element count. An empty sequence has length zero. `ByteArray` uses `lf_byte_array` with the same fields. `Prod α β` uses a pair struct with `fst` and `snd`.
- `Except ε α` in a return type writes the success value to `out`. An error returns `LF_EXCEPT` and stores a UTF-8 JSON representation of the payload in `lf_error.message` when an error pointer is provided. An enclosing `IO` failure returns `LF_IO`.

Public function names use the module prefix and the snake case form of the final component of the Lean declaration name. Type names use the module prefix, the snake case form of the qualified Lean name, and the concrete type arguments. Pairs use `pair` as the base name. Generated identifiers that match a C keyword get a trailing underscore. A collision stops generation. Repeat `--rename Lean.Name=c_name` to choose names for individual functions, types, constructors, or fields using their qualified Lean names.

## Ownership

Generated functions borrow inputs, including all pointed-to data, for the duration of the call. Pass a pointer to a borrowed value for each composite argument. For output, provide writable storage and release any owned value in that storage before a new call writes to it.

On a successful call, the caller owns the output's nested allocations. Pass the output to the generated `<type>_free` function to release its nested strings, arrays, and recursive fields and clear the value in place. The function leaves the outer storage available to its owner. Use `lf_nat_free`, `lf_int_free`, or `lf_byte_array_free` for the common types and `lf_free(out.ptr)` for a top-level `lf_str`.

## Validation and JSON

Call `<type>_valid(&value, &error)` to check a C value before passing it to an exported function. The generated wrappers also check their inputs, including values nested in arrays, records, and variants. A failed Lean invariant returns `LF_INVALID` and identifies the Lean type and proof field. Generation exits with status 254 if it cannot synthesize a computable `Decidable` instance.

The generated header declares `<type>_to_json(&value, &json, &error)` and `<type>_from_json(data, len, &value, &error)`. Free the encoded JSON with `lf_free(json.ptr)` and free decoded values using the same ownership rules as other outputs. The decoder takes a UTF-8 byte range and checks the same invariants when it constructs the Lean value. For example, when `Pricing.total` exposes `UInt64`, `pricing_uint64_to_json` encodes the result as a quoted decimal string.

Records use Lean field names, enums use constructor names, and variants with payloads use objects with a single constructor key. A record field named `field?` is emitted as `field` when its option holds a value. `none` encodes as `null`, so nested options with the same JSON representation decode to the outer `none`. `Nat` and `Int` use decimal JSON numbers. `UInt64` and `USize` use quoted decimals. The generated JSON parser accepts up to 1024 nested levels. For integer fields, scientific notation can append up to 10000 decimal zeros. Decimal digits can be supplied directly for larger integers.

Generation writes `<prefix>.schema.json` in draft 2020-12. A single API type appears at the document root. With multiple API types, select the type in `$defs` using the part of the function name before `_to_json`. The schema follows the Go backend's rules for field bounds and recursive references.

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
