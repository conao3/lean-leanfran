# C guide

`leanfran-c` generates a C11 API for definitions in a Lean 4.35.0 Lake library. The generated header also works with C++.

## Set up the compiler

From the leanfran repository root, run `nix build .#c` and add `result/bin` to your PATH. To build with elan, run `lake build leanfran-c` in `langs/C` and add its `.lake/build/bin` to your PATH. Use Lean 4.35.0 and a C compiler in the consuming workspace. The clang bundled with an elan toolchain does not find the system C headers on NixOS, so build there inside `nix develop .#c`. The linking examples use pkg-config, GNU Make, or CMake.

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

A block starts at a `/* leanfran:lean <name>` line and ends at the next `*/`. The name is an ASCII C identifier other than `lf` or `leanfran`, in any letter case. It becomes the C prefix and the Lean module `LeanfranBlocks.<name>`. A line `imports: <name>, …` directly after the first line imports other blocks, and the importing block uses their definitions by their unqualified names. The block's Lean code can begin with `import` lines for modules of the `[[require]]` packages and for `LeanCLib.C`, which defines the C operations and `C.Status` used in [Verify a C function in Lean](#verify-a-c-function-in-lean). A Lean string that needs `*/` can write it as `"*" ++ "/"`.

Put `leanfran.toml` in the project root. The commands stop with status 254 when it is missing, and a file with only `sources` is enough.

```toml
# leanfran.toml
sources = ["src/**/*.c", "src/**/*.h"]
lean-files = ["lean/*.lean"]
out-dir = "leanfran"
cflags = ["-Isrc/include"]

[[require]]
name = "pricing_rules"
path = "../pricing-rules"
```

| Key | Meaning |
| --- | --- |
| `sources` | Glob patterns for C files to scan. `**` matches any number of directories. |
| `lean-files` | Lean files added as blocks. The file name is the block name. |
| `out-dir` | Output directory inside the project. The default is `leanfran`. |
| `cflags` | Compiler flags clang uses to read files with `LF_STRUCT` or `LF_MODEL` that `compile_commands.json` does not cover. |
| `[[require]]` | Lake dependencies, copied to the workspace. A relative `path` is resolved from the project root. |

The output directory contains `<name>.h` for each block, `leanfran.h`, `libleanfran.a`, `leanfran.pc`, `leanfran.mk`, `leanfran-config.cmake`, and `leanfran.manifest.json`. `leanfran_init` initializes every block, and each `<name>_init` calls it. Link with the generated settings as described in [Link the library](#link-the-library), using `leanfran` as the package name.

- `leanfran-c sync` builds with warnings treated as errors, so a failed proof or a `sorry` stops the build. Lean diagnostics use the C file and line, as in `src/pricing.c:12:5: error: …`. A failure leaves the previous output directory unchanged.
- `leanfran-c status` exits with status 1 and names each changed block, `leanfran.toml`, `LF_STRUCT` inputs, the compiler version, or a missing output file. It exits with status 0 when the output is current.
- `leanfran-c check` runs `sync`, checks the `LF_MODEL` obligations described in [Verify a C function in Lean](#verify-a-c-function-in-lean), and then runs `status`.

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

`LF_STRUCT` and `LF_FIELD` expand to clang `annotate` attributes and to nothing for other compilers. `sync`, `status`, and `check` read the files with `LF_STRUCT` or `LF_MODEL` using `clang -Xclang -ast-dump=json`, so a project that uses either needs clang on `PATH`. clang takes a file's flags from the first entry for that file in `compile_commands.json` in the project root. A header uses the flags of the first entry that includes it. Files without an entry use `cflags`. clang also searches the output directory for headers, so a C file can include a block's generated header by name.

## Verify a C function in Lean

Put `LF_MODEL(...)` from `leanfran.h` before a C function and write the specification in a Lean block. `leanfran-c check` translates the function from clang's JSON AST into a Lean definition and checks the proofs you write about it.

```c
/* leanfran:lean clamp
def spec (lo hi x : Int32) : Int32 := if x < lo then lo else if x > hi then hi else x
def ordered (lo hi _x : Int32) : Bool := lo ≤ hi
*/
#include "leanfran.h"

LF_MODEL("refines=spec", "requires=ordered")
int32_t clamp(int32_t lo, int32_t hi, int32_t x) {
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}
```

| `LF_MODEL` argument | Meaning |
| --- | --- |
| `refines=<name>` | A Lean function with the same arguments that returns the expected result. For a function that returns `lf_status` with an `out` pointer, the result is `C.Status × Option T`, where `T` is the Lean type of `*out`. |
| `requires=<name>` | A Lean function with the same arguments that returns `Bool`. Every obligation assumes it returns `true`. |
| `ensures=<label>:<name>` | A Lean function returning `Bool` that takes the arguments followed by the result. Use a distinct label for each postcondition. |
| `spec=<block>` | The Lean block that contains the names. The default is the only block in the file that contains `LF_MODEL`. |

Give at least one `refines=` or `ensures=`. An `LF_MODEL` on a declaration in a header applies to the definition. Mark a read-only array argument with `LF_ARRAY(<length argument>)` after a `const T *` parameter. The Lean definition takes an `Array` and derives the length argument from its size. `LF_MODEL` and `LF_ARRAY` expand to clang `annotate` attributes and to nothing for other compilers. `sync` reads `LF_MODEL` functions to generate the [model test](#model-test), so `sync`, `status`, and `check` need clang on `PATH`.

### Obligations and proof status

`check` writes the translation of each function and its callees to the module `LeanCModel.<block>` in `.leanfran/workspace`. Each obligation is an abbreviation such as `clamp.obligation.refines`. It quantifies over the arguments, assumes for each `LF_ARRAY` argument that its size fits the length argument's type (`xs.size < 2 ^ 64` for `size_t`, `2 ^ 31` for `int32_t`), and then assumes `requires`. Prove it in `lean/Proofs/*.lean` with a declaration named `clamp.proof.refines` in the namespace `LeanCModel.<block>`.

```lean
import LeanCModel.clamp

namespace LeanCModel.clamp

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro lo hi x _
  simp only [clamp, spec, Id.run]
  split <;> (try split) <;> rfl

end LeanCModel.clamp
```

A function whose body can hit undefined behavior returns `C.M α`, which is `Except C.Exc α`. Signed overflow, division by zero, a shift count that is negative or not less than the width, a `double` to integer conversion out of range, an out-of-range array index, a read of an inactive tagged-union member, a non-terminating loop, and reaching the end of a function that returns a value are modeled failures. Refinement then means the translated function returns `Except.ok` with the specified value, so a proof also shows that the failures do not occur on inputs that satisfy `requires`. A postcondition for such a function states that a successful result exists and satisfies the predicate.

```sh
leanfran-c check --require proved
leanfran-c status
```

`check` prints one line per obligation, such as `clamp.clamp [refines]: proved`, and writes `leanfran.lock` in the project root with the states and SHA-256 hashes of the inputs.

| State | Meaning |
| --- | --- |
| `proved` | The declaration has the obligation's type and depends only on `propext`, `Quot.sound`, and `Classical.choice`. |
| `sorry` | The declaration depends on `sorryAx`. |
| `axioms` | The declaration depends on another axiom. This includes tactics that add a native-computation axiom. |
| `missing` | The proof declaration is absent. |
| `mismatch` | The declaration's type differs from the obligation. |
| `failed` | A proof file that declares the proof fails to build. |
| `unextracted` | The function is outside the translated subset or its translation does not elaborate. The diagnostic gives the C file, line, column, and reason. |
| `stale` | `status` found a change to the function, a function it calls, a struct it uses, the spec block, the proofs, `leanfran.toml`, or the compiler since the lock was written. |

`check --require proved` exits with status 1 unless every obligation is `proved`. Plain `check` exits with status 1 when a function is `unextracted` or a proof fails to build. `status` reads the lock and exits with status 1 when an obligation is stale.

### C subset and proof scope

The translator accepts `static` and external functions with these parts.

- Types: `int8_t` to `int64_t`, `uint8_t` to `uint64_t`, `int` and `unsigned` (32 bits), `long` and `unsigned long` (64 bits), `size_t`, `bool`, `double`, `LF_STRUCT` structs and the generated record types passed by value, the generated enums and tagged unions passed by value, other C enums as their underlying integer type (`unsigned int`, or `int` when an enumerator is negative), and `LF_ARRAY` arrays. An `LF_ARRAY` element and the `out` pointee can be any of these value types, including generated enums and tagged unions. A function returns one value, or `lf_status` with a final `out` pointer. An `LF_ARRAY` parameter and the `out` pointer can be `restrict` (`const T *restrict xs LF_ARRAY(n)`, `T *restrict out`). A function whose `out` pointee has the same type as the element of an `LF_ARRAY` parameter must declare that parameter or `out` `restrict`.
- Generated enums: a value is the Lean constructor. Conversions to integers give the constructor number, so comparisons and `switch` on enumerators work. A conversion from an integer to a generated enum must be an enumerator or a constant that names a constructor.
- Generated tagged unions: a value is the Lean value. `x.tag` is the constructor number. `x.as.<constructor>.<field>` reads a field of the active constructor; reading a member of another constructor fails the translated definition with `C.Exc.inactiveMember`, so a `refines` proof also shows that the function reads only the active member.
- Statements: local declarations with initializers, assignment, compound assignment, `++`, `--`, `if`, `switch` with `break`-terminated cases, `for`, `while`, `do while`, `break`, `continue`, and `return`.
- Expressions: integer and `double` arithmetic, comparisons, bitwise operators and shifts, `&&`, `||`, `!`, `?:`, array and field reads, integer conversions, and calls to other translated functions.
- Calls with arrays: pass one of the caller's `LF_ARRAY` parameters as an array argument. If the length argument is that parameter's own length argument and the caller never assigns it, the callee receives the whole array. Any other length `n` passes the first `n` elements. A negative `n` or an `n` larger than the array is an out-of-range index.
- Calls with an `out` pointer: a call to a function that returns `lf_status` with an `out` pointer can be an expression statement or an `lf_status` local's initializer. It can also be assigned to an `lf_status` local, returned, or compared with an `LF_` constant as the whole condition of an `if` or a loop. The `out` argument is `&x` for a local variable or parameter `x` of the pointee type, or the caller's own `out` pointer. If the callee writes `*out`, the call stores the value in `x`. Otherwise `x` keeps its previous value. `lf_status` values support `==` and `!=`, and a status function can return them.

Keep other pointers, array arguments other than `LF_ARRAY` parameters, `lf_status` calls inside other expressions, `lf_status` values used as integers, assignments, `++`, `--`, and the comma operator used as values, writes to fields and array elements (including `tag` and the `as` members of a tagged union), struct literals, payload structs (`<type>_<constructor>_fields`) used as values, pointer fields of recursive tagged unions, `malloc` and `free`, globals and `static` locals, I/O, `goto`, recursion, variadic functions, other unions, function pointers, `volatile`, uninitialized locals, `switch` fallthrough, string literals, the floating-point environment outside modeled functions, and an `out` pointer next to an `LF_ARRAY` parameter of the same element type with neither declared `restrict`. `check` reports a function that uses any of them as `unextracted` with the C file, line, column, and reason. Implementation-defined behavior follows GCC and Clang: right shifts of negative values are arithmetic, and conversions to signed types wrap. `double` operations use Lean's `Float`.

A `proved` obligation is a theorem about the translated definition. The translated definition reads each array as an immutable Lean `Array`, so a write through `out` does not reach it, and the obligation holds for calls whose `out` overlaps no `LF_ARRAY` argument. Callers must keep `out` apart from every `LF_ARRAY` argument. With `restrict`, a call that writes an element through `out` and reads it through the array is undefined behavior in C. `check` does not detect overlaps that C allows between different types: a character-type `out`, integers of the same width that differ only in sign, an enum and its integer type, and a struct `out` with a field of the element type. The trusted pieces outside each proof are the translator, clang's AST, [the operation model](../langs/C/lean/LeanCLib/C.lean), and the C compiler. The repository tests them. The operation tests compare `LeanCLib.C` with GCC and Clang at `-O0` and `-O2` and match each modeled failure with the UBSan diagnostic. The translation tests compare translated functions with the compiled C. Inputs that make a translation fail must stop the C function under UBSan, and inputs that make it fail with a first out-of-range index at most 16 elements outside the array must stop the C function under ASan, which reads arrays allocated with their exact length. ASan does not detect a read that lands in another live allocation, and UBSan does not detect a read of an inactive tagged-union member, so the tests do not compare those reads with C. The model test below runs your implementation against the spec.

### Model test

When the sources contain `LF_MODEL`, `sync` also writes `leanfran_model_test.c` and `leanfran_model_test.h` to the output directory and a `leanfran-model-test` target to `leanfran.mk`. The test calls the spec through the block's public C function and compares it with your C function. It enumerates boundary values first and then uses seeded random inputs, and it discards inputs that `requires` rejects. NaN results match each other, and other `double` results are compared bit for bit.

```sh
make -f leanfran/leanfran.mk leanfran-model-test
LEANFRAN_RUNS=10000 LEANFRAN_SEED=7 make -f leanfran/leanfran.mk leanfran-model-test
```

The `clamp` example prints `clamp.clamp: 109 inputs passed (seed 1)`. An implementation that returns `hi - 1` when `x >= hi` fails on the first boundary input.

```text
clamp.clamp [refines]: mismatch (seed 1, run 0)
  input: lo=0, hi=0, x=0
  expected: 0, got: -1
```

The target builds the test with your source files that contain the modeled functions, using `$(CC) -fno-wrapv -fsanitize=undefined,float-cast-overflow -fno-sanitize-recover=all` with `$(CFLAGS)` and `cflags` from `leanfran.toml`. UBSan stops the test at the first undefined behavior in your C code. A mismatch prints the seed, the run, the input, and both results. In both cases the test exits with status 1. `LEANFRAN_RUNS` sets the number of inputs (200 by default) and `LEANFRAN_SEED` sets the seed (1 by default). Including `leanfran.mk` in a Makefile leaves its default goal unchanged.

Generated enums and tagged unions can be arguments and results. Every enum constructor is a boundary value. A tagged-union argument takes each constructor without proof fields, with boundary and random values for its fields. A function whose tagged-union argument has only constructors with proof fields is skipped. Results are compared by value: an enum by its constructor, and a tagged union by its tag and then by each field of the active constructor. A mismatch prints these values by their C names, such as `kinds_shape_rect{w=0, h=0, level=kinds_level_low}`. Payload fields can be the integer, `bool`, `double`, and generated enum types.

The test does not cover `static` functions, `lf_status` results, `out` pointers, structs, generated enums or tagged unions as array elements, tagged unions with other field types, or specs whose public C function has a different signature. It prints a `skipped:` line with the reason for each. The source files the test links must not define `main`. Nix's C compiler wrapper adds `-fwrapv` through its hardening flags. The target's `-fno-wrapv` turns it off so UBSan reports signed overflow.
