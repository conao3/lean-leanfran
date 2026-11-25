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

## Value handles

A value handle is an owned reference to a Lean value. Use handles to pass a value through several calls while keeping its Lean representation. The generated header declares a `<type>_ref` struct for each type. For built-in types the name includes the module prefix, `type_`, and a Lean type stem, such as `pricing_type_uint64_ref` or `pricing_type_string_ref`. Use a zero-initialized struct for an empty handle and treat its `obj` field as opaque.

| Operation | Ownership |
| --- | --- |
| `<type>_ref_from(&value, &handle, &error)` | Borrows the C value and returns an owned handle. |
| `<type>_ref_get(handle, &value, &error)` | Borrows the handle and returns a C value with the usual output ownership. |
| `<type>_ref_retain(handle)` | Returns another owned reference to the same Lean value. |
| `<type>_ref_release(handle)` | Releases one owned reference. An empty handle is safe to release. |
| `<prefix>_<function>_ref(..., &handle, &error)` | Borrows its handle arguments and returns an owned handle on success. |
| `<prefix>_<function>_ref_take(..., &handle, &error)` | Transfers one owned reference per argument to Lean and returns an owned handle on success. An exclusive array can reuse its storage. |

Assigning a handle struct copies its pointer. Call `_ref_retain` whenever two owners need separate references. Release an owned output before reusing its storage. Unit-returning functions keep the status-only signature. `_ref_take` checks module initialization, empty inputs, and the output pointer before consuming any arguments. Once Lean runs, it consumes the arguments even if it returns `LF_EXCEPT` or `LF_IO`. Discard the transferred input handles and use the output only on success. Use an input handle’s own storage for the output when the types match and you intend to replace the transferred reference. If Lean returns an error, clear that slot before using it again.

### Call from another thread

`<prefix>_init` attaches its caller to the Lean runtime. After module initialization, call `lf_thread_attach()` on each additional C thread before it uses Lean. Call `lf_thread_detach()` when the thread is done with Lean, after releasing its references. Repeated attach calls on the same thread need a single detach.

Call `<type>_ref_share(handle)` on the owning thread before publishing a handle to another thread. Publish it with ordinary thread synchronization, such as passing it to `pthread_create`. Sharing marks the Lean value and its reachable objects for atomic reference counting. The caller still owns the same reference. Keep a reference alive while another thread borrows it, or transfer or retain a reference for that thread to release.

### Performance

On an Intel Core i5-8400 with the standard Nix C development shell and Lean 4.35.0, summing an array of 100 line items took 7.485 µs per call through the ordinary public function and 0.078 µs per call through the value handle function. Each timing averages 100,000 calls. Each row contains a string, a quantity, and a price. The handle timing reuses an input handle created before the timed loop and includes reading and releasing each result handle. Run `nix shell nixpkgs#gnumake -c make check BACKENDS=C` from the repository root to run the same benchmark.


## Embed Lean in C sources

`leanfran-c sync` reads Lean from block comments in C files, builds them in a Lake workspace under `.leanfran/workspace`, and writes the headers, one static library, and link settings to an output directory. The C project does not need to be a Lake project. Add `.leanfran/` to `.gitignore`.

```c
/* leanfran:lean pricing
def total (items : Array (UInt32 × UInt32)) : Nat :=
  items.foldl (fun acc (qty, price) => acc + qty.toNat * price.toNat) 0

theorem total_empty : total #[] = 0 := rfl
*/
#include "pricing.h"
```

A block starts at a `/* leanfran:lean <name>` line and ends at the next `*/`. The name is an ASCII C identifier other than `lf` or `leanfran`, in any letter case. It becomes the C prefix and the Lean module `LeanfranBlocks.<name>`. A line `imports: <name>, …` directly after the first line imports other blocks. A Lean string that needs `*/` can write it as `"*" ++ "/"`.

```toml
# leanfran.toml
sources = ["src/**/*.c", "src/**/*.h"]
lean-files = ["lean/*.lean"]
out-dir = "leanfran"
cflags = ["-Isrc/include"]

[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4"
rev = "v4.35.0"
```

| Key | Meaning |
| --- | --- |
| `sources` | Glob patterns for C files to scan. `**` matches any number of directories. |
| `lean-files` | Lean files added as blocks. The file name is the block name. |
| `out-dir` | Output directory inside the project. The default is `leanfran`. |
| `cflags` | Compiler flags clang uses to read `LF_STRUCT` files that `compile_commands.json` does not cover. |
| `[[require]]` | Lake dependencies, copied to the workspace. A relative `path` is resolved from the project root. |

The output directory contains `<name>.h` for each block, `leanfran.h`, `libleanfran.a`, `leanfran.pc`, `leanfran.mk`, `leanfran-config.cmake`, and `leanfran.manifest.json`. `leanfran_init` initializes every block, and each `<name>_init` calls it. Link with the generated settings as described in [Link the library](#link-the-library), using `leanfran` as the package name.

- `leanfran-c sync` builds with warnings treated as errors, so a failed proof or a `sorry` stops the build. Lean diagnostics use the C file and line, as in `src/pricing.c:12:5: error: …`. A failure leaves the previous output directory unchanged.
- `leanfran-c status` exits with status 1 and names each changed block, `leanfran.toml`, `LF_STRUCT` inputs, the compiler version, or a missing output file. It exits with status 0 when the output is current.
- `leanfran-c check` runs `sync` and then `status`.

### Use C structs in Lean

Mark a struct with `LF_STRUCT(<block>)` and its fields with `LF_FIELD("<constraint>", …)` from `leanfran.h`. `sync` adds a Lean structure with the same name before the block. Each constraint becomes a proof field named `<field>_<key>`.

```c
#include "leanfran.h"

typedef struct LF_STRUCT(pricing) order {
    uint32_t qty LF_FIELD("ge=1", "le=1000");
    int64_t price_cents LF_FIELD("ge=0");
    lf_str sku LF_FIELD("min_len=1", "max_len=8");
} order;

typedef struct {
    order *items;
    size_t len;
} order_list;

typedef struct LF_STRUCT(pricing) {
    order_list orders LF_FIELD("max_len=4");
    bool express;
} cart;
```

```lean
def cartTotal (c : cart) : Int :=
  c.orders.foldl (fun acc o => acc + Int.ofNat o.qty.toNat * o.price_cents.toInt) 0
```

| Constraint | Field types | Lean proposition |
| --- | --- | --- |
| `ge=n`, `gt=n`, `le=n`, `lt=n` | Integer scalars, `lf_nat`, `lf_int` | The field's integer value compared with `n` |
| `min_len=n`, `max_len=n` | `lf_str`, `lf_byte_array`, arrays | `String.length` or `size` compared with `n` |

Fields use `bool`, the fixed-width integer types, `size_t`, `float`, `double`, `lf_str`, `lf_nat`, `lf_int`, `lf_byte_array`, another `LF_STRUCT` struct, or a struct with exactly `T *items` and `size_t len` for `Array T`. Any other field type, an unknown block, or a constraint that does not fit the field type stops `sync` with status 254 at the field's position.

Declare `LF_STRUCT` structs in a header that includes `leanfran.h`. The block's generated header includes that header by a path relative to the output directory and defines `<prefix>_<name>` as an alias, so the C program passes its own struct to the generated functions. The wrappers check each constraint and return `LF_INVALID` with the type and proof field, as in `Invalid order.qty_ge`.

`LF_STRUCT` and `LF_FIELD` expand to clang `annotate` attributes and to nothing for other compilers. `sync` reads the marked files with `clang -Xclang -ast-dump=json`, so clang must be on `PATH` only for projects that use `LF_STRUCT`. clang takes each file's flags from `compile_commands.json` in the project root. A header uses the flags of the first entry that includes it. Files without an entry use `cflags`.

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
