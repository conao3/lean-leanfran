# PHP guide

[leanfran](../README.md) · [PHP quick start](../langs/PHP/README.md) · [Samples](../langs/PHP/samples/README.md)

## Installation

Generation uses Lean 4.35.0 and the `leanfran-php` compiler. Follow the [quick start](../langs/PHP/README.md) to build the compiler with Nix and install the runtime from a Composer path repository. Running the generated code requires 64-bit PHP 8.4 or later, `ext-gmp`, and `ext-tokenizer`.

## Embedded Lean

Put `#[Conao3\Leanfran\Lean(...)]` on a PHP class. Its fully qualified name identifies the block. The attribute takes four arguments.

| Argument | Purpose |
| --- | --- |
| `source` | Lean source in a nowdoc or a single-quoted PHP string literal. |
| `imports` | Lean modules to import, such as `['Std.Data.HashMap']`. |
| `uses` | Block classes whose Lean definitions are in scope, such as `[Orders::class]`. Their generated public PHP types are shared. |
| `models` | PHP classes to import as Lean structures or enum types, such as `[LineItem::class]`. |

The last three arguments are optional literal arrays. Class names can be written as fully qualified strings or `ClassName::class` literals. See [embed-range](../langs/PHP/samples/embed-range) for a complete block and [embed-orders](../langs/PHP/samples/embed-orders) for two blocks that share an `Order` type.

For `App\Pricing` in `src/Pricing.php`, leanfran writes the `App\Pricing\Functions` trait and public types such as `App\Pricing\Range` to `src/Pricing/`. The implementation lives under `src/Pricing/Internal/`, and `src/Pricing/leanfran.json` records the block hash and generated files. In the block class, add `use Pricing\Functions;` so callers can use `App\Pricing::width()`. Map `App\` to `src/` in the Composer PSR-4 autoloader.

### Commands and configuration

Run the Composer binary from the application directory. Pass `--package dir` to select a package in another directory.

| Command | Effect |
| --- | --- |
| `vendor/bin/leanfran sync` | Scans the package, builds the blocks in `.leanfran/workspace`, and replaces their generated PHP and manifests after every block succeeds. |
| `vendor/bin/leanfran status` | Reports stale or removed blocks, missing generated files, and saved proof states. It runs without Lean and exits 1 if outputs or proof results are stale. |
| `vendor/bin/leanfran check` | Runs `sync`, translates PHP models, and checks their Lean proofs. Accepts `--require proved` to enforce a proof policy. |

Commit the generated PHP and manifests. In CI, install Composer dependencies and run `vendor/bin/leanfran status` to verify that the checkout is up to date. Run `check` in jobs that also verify Lean proofs and regenerate the PHP. The CLI keeps its Lake workspace under the ignored `.leanfran/` directory.

In `composer.json`, set `extra.leanfran.paths` to a list of package directories to scan. By default, the CLI scans the directories listed in `autoload.psr-4`. Set `extra.leanfran.require` to a list of Lake requirements using the keys from `[[require]]` in a Lake TOML file. Relative dependency paths resolve from the Composer package directory. Composer scripts can run the binary, for example `"lean:sync": "leanfran sync"`.

For `sync` and `check`, the compiler is selected by `--leanfran-php`, then `LEANFRAN_PHP_CLI`, then `leanfran-php` on PATH. Its `--generator-version` must match the installed Composer runtime. The CLI uses `lean` and `lake` from PATH. Both must match the package's `lean-toolchain`, which defaults to Lean 4.35.0.

A Lean error in a block starts with the PHP file, line, and column. The message also gives the block's fully qualified PHP class name and the Lean line and column within its source string. When a block fails to build, the previous generated PHP remains available. Proofs of PHP models run after sync has installed the generated files.

### Importing PHP models

A model is a final class whose instance data consists of promoted public readonly properties on its public constructor, or a backed enum. Composer must be able to autoload model classes and any classes used by their properties. Block discovery reads PHP tokens, and model discovery loads the model classes for Reflection, including during `status`. Referenced models are imported transitively, and their references must be acyclic.

Reflection supplies native types. The CLI resolves PHPDoc class names in the namespace and imports of the constructor declaration. It reads constructor `@param` types and promoted property `@var` types, with `@var` taking precedence when both are present. A native `array` needs a list or pair annotation. An unsupported type produces a diagnostic with the class and property.

| PHP or PHPDoc type | Lean representation |
| --- | --- |
| `int` | `Int` |
| `int<a, b>` | `Nat` if the lower bound is nonnegative, otherwise `Int`, with inclusive bounds as applicable. Use `min` or `max` for an unbounded endpoint. |
| `positive-int`, `non-negative-int` | `Nat`, with a lower-bound proof for `positive-int`. |
| `negative-int` | `Int` with an upper-bound proof at −1. |
| `float`, `bool`, `string` | `Float`, `Bool`, `String` respectively. |
| `non-empty-string` | `String` with a minimum length of 1. |
| `list<T>`, `non-empty-list<T>` | `List T`, with a minimum length of 1 for `non-empty-list<T>`. |
| `array{0: A, 1: B}` | `A × B` |
| `?T` or `T\|null` | `Option T` |
| Model class | A structure under `LeanPhpModels` with the PHP namespace and class name. |
| Backed enum | An inductive type with a nullary constructor for each PHP case name. |

Bounds and minimum lengths become Lean proof fields such as `percent_le`, `quantity_ge`, and `items_min_items`. The generated PHP accepts the original class and validates its properties before constructing the Lean value. For example, passing 101 in a field annotated `int<0, 100>` raises `Conao3\Leanfran\ValidationError` with the argument and property in the issue path. The generated code reconstructs returned models by calling the original constructor with named arguments. A change to a model's Lean representation makes its block and dependent blocks stale.

## Verifying PHP functions

Attach `#[Conao3\Leanfran\Model(...)]` to a typed static method or a named function. The attribute binds the function to executable Lean specifications in a `#[Lean]` block. The [quick start](../langs/PHP/README.md#verify-a-php-function) walks through `clamp`. The [cart sample](../langs/PHP/samples/verified-cart) proves a summation loop correct when every price and the list length are bounded.

| Argument | Purpose |
| --- | --- |
| `refines` | Lean function that takes the PHP arguments in the same order and returns the specification's result. The proof establishes equality with that result. |
| `requires` | Lean function that takes the arguments and returns `Bool`. Every obligation assumes it returns `true`. |
| `ensures` | Literal map from obligation labels to Lean functions taking the arguments followed by the result and returning `Bool`. Use distinct labels other than the reserved `refines`. |
| `spec` | Class containing the `#[Lean]` block, written as a fully qualified string or a `ClassName::class` literal. Defaults to the declaring class for a method. Specify it on a namespace function. |

Use names relative to the selected block. A dotted name can select a Lean declaration in a namespace within the block. Each option is optional when the block can be inferred. A property test needs at least one `refines` or `ensures` oracle. Install `nikic/php-parser` as a development dependency in the application that declares the models. With Packagist enabled, run the following from its Composer directory.

```sh
composer require --dev --no-interaction 'nikic/php-parser:^5.9'
```

### PHP subset

The translator expects by-value parameters and return values, locals with consistent types, and a return or throw on every path. A call to another modeled function must resolve statically within the same project, pass all arguments positionally, and avoid recursive cycles.

| Area | Supported forms |
| --- | --- |
| Parameters and results | `int` → `Int`, `bool` → `Bool`, `string` → `String`, `float` → `Float`, and native `?T` → `Option`. Use PHPDoc `list<T>` or `array{0: A, 1: B}` on native `array` for a Lean list or pair. |
| Value types | Backed enums and final classes with promoted public readonly properties. Supported generated public value types are enums and structures with representable fields. Construction in the translated body requires a structural constructor. A generated constructor's supported invariant checks translate to failure branches. |
| Statements | Local assignment and reassignment, two-element tuple destructuring, `+=`, `-=`, `*=`, `.=`, and integer increment and decrement as statements. Also `if`/`elseif`/`else`, early `return`, `foreach` over lists with or without the index, `for`, `while`, single-level `break`/`continue`, `throw new X(...)`, and append to a list created in the function. |
| Expressions | Integer `+`, `-`, `*`, `%`, unary minus, and `intdiv`. Float `+`, `-`, `*`, `/`, and unary minus. Same-type `<`, `<=`, `>`, and `>=` for numbers and booleans. Strict equality and inequality on same-type scalars and enum cases, or when comparing a nullable value with `null`. Boolean `&&`, `\|\|`, and `!`, ternaries, `match`, list indices, constant tuple indices, property reads, enum cases, list and pair literals, and structural `new`. |
| Built-ins | `count` for a list or pair, `abs` for a number, two-argument `min` and `max` on same-type numbers, `strlen` for the byte length of a string, and `.` for string concatenation. |

Outside this subset are missing parameter or return types, `mixed`, general unions, unannotated arrays, associative arrays, integer `/`, loose comparisons (`==`, `!=`, `<=>`), and object, list, or tuple operands to `===` or `!==`. PHP object comparisons use identity. The subset also excludes invalid UTF-8 strings, interpolation, string indexing, `??`, references, variadic parameters, PHP globals and static locals, property writes, dynamic calls, generators, I/O, and exception handlers. Unsupported syntax produces a source location and an `unextracted` state.

### Translation and proof scope

Lean models the body using `do` notation. An infallible body uses `Id.run`. A body with a modeled failure or a call to a fallible function uses `Php.M α`, an alias for `Except Php.Exc α`. The rules are implemented in [LeanPhpLib.Php](../langs/PHP/src/lean/LeanPhpLib/Php.lean).

| PHP operation | Lean behavior |
| --- | --- |
| Integer addition, subtraction, multiplication, negation and `abs` | Arithmetic on `Int`, checked against the signed 64-bit range. When PHP promotes the result to a float, the model returns `overflow`. |
| `intdiv` | Division truncating toward zero. A zero divisor gives `divisionByZero`. Dividing `PHP_INT_MIN` by −1 gives `arithmeticError`. |
| `%` | Remainder with the dividend's sign. A zero divisor gives `divisionByZero`. |
| Float division | A zero divisor gives `divisionByZero`. |
| List indexing | Negative or out-of-range indices give `undefinedIndex`, corresponding to PHP's warning and null result. |
| `match` | A match with no matching arm or default gives `unhandledMatch`. |
| `throw new X(...)` | A failure carrying the exception class name. |

The proof describes the translated function under its input contract. PHP strings must contain valid UTF-8, arrays must have the list or pair shape in their PHPDoc, and numbers must follow the PHP types at the boundary. String equality compares byte sequences and `strlen` counts UTF-8 bytes. Proofs establish partial correctness for executions represented by the model, including integer arithmetic within its checked bounds. They rely on the translator and its model of PHP operations. A proved refinement of a fallible translation also establishes that it returns `Except.ok` on inputs satisfying the precondition. A postcondition alone constrains successful results.

The logical assumptions are the `requires` predicate and the invariants of supported generated public types that their constructors validate. PHPDoc supplies the shape of a list or pair. PHPDoc bounds such as `int<0, 100>` and length refinements supply no assumptions. Put those conditions in `requires` if the proof needs them. A verified function cannot use an imported PHP value type whose Lean representation assumes stronger PHPDoc constraints. A standalone PHP value type is translated using just its shape.

### Obligations and proof status

The translated name is `LeanPhpModel.<namespace>.<class>.<method>` for a method, with the class component omitted for a namespace function. The translator writes an `abbrev <function>.obligation.<label> : Prop` for each refinement and postcondition. Each obligation universally quantifies the arguments and includes the precondition when present. A refinement equates the result with the spec, wrapped in `Except.ok` for a fallible body. A postcondition says the predicate on the arguments and result is true. For a fallible body it says so for every result returned via `Except.ok`.

Place Lean modules under `lean/Proofs/` beside `composer.json`. Import the generated model module and prove `<function>.proof.<label>` with the corresponding obligation as its type. Open the block's `LeanPhpEmbed.<namespace>.<class>` aliases to refer to the specifications. The following theorem appears in the [clamp proof file](../langs/PHP/samples/verified-clamp/lean/Proofs/Calc.lean).

```lean
import LeanPhpModel.App.Calc

open LeanPhpEmbed.App.Calc
namespace LeanPhpModel.App.Calc

theorem clamp.proof.refines : clamp.obligation.refines := by
  intro x lo hi h
  simp only [ordered, decide_eq_true_eq] at h
  simp only [clamp, clampSpec]
  split <;> (try split) <;> simp_all <;> omega

end LeanPhpModel.App.Calc
```

`vendor/bin/leanfran check` syncs the blocks, translates the modeled functions, builds their Lean definitions and proofs, and writes proof results and input hashes to `leanfran.lock`. It prints a state per obligation.

| State | Meaning |
| --- | --- |
| `proved` | The theorem's type is definitionally equal to the obligation and its axioms are limited to `propext`, `Quot.sound`, and `Classical.choice`. |
| `sorry` | The proof depends on `sorryAx`. |
| `axioms` | The proof depends on an axiom outside the allowed set. |
| `failed` | A proof file declares the expected proof but fails to build. |
| `missing` | The expected theorem is absent from the built proof modules. |
| `mismatch` | The theorem's type differs from the obligation. |
| `unextracted` | The translator or Lean could not produce the obligation. |

With `--require proved`, `check` exits 1 if any obligation has a state other than `proved`. Without the flag, `check` still exits 1 for an unextracted obligation, stale or missing block outputs, or a command or build error that aborts the check. `status` runs without Lean, parses the model source using the same PHP parser, and reads the lock and block manifests. It reports a model as `stale` when its saved result is missing or its model body, dependencies, selected Lean block, or translation inputs have changed. Stale or missing outputs, stale proof results, and command errors produce exit 1. A fresh saved non-proved state can still give a successful `status`.

### Property tests and CI

`Conao3\Leanfran\Verify::checkModel(callable $f, int $runs = 200, int $seed = 1): void` runs one model. `Verify::checkClass(string $class): void` runs the annotated methods declared by that class with the defaults. Pass `[Calc::class, 'clamp']` to test just that method. Call either entry point from PHPUnit or a standalone PHP script. The [clamp sample](../langs/PHP/samples/verified-clamp/main.php) calls `checkClass` before printing its result.

The tester uses the configured Composer scan paths and runs the selected block's generated PHP wrappers. Run `sync` or `check` first and keep the generated files and PHP parser available. Preserve the generated methods’ PHPDoc when using OPcache. The tests themselves run without Lean. Boundary cases include 0, ±1, the integer limits, empty lists and strings, and single ASCII and non-ASCII characters. The tester then uses a local seeded `Mt19937` engine. Random strings have up to eight Unicode scalars, lists have up to eight elements, and nested list and nullable values are depth-limited. Float inputs are finite.

Inputs that fail a generated value check or whose `requires` predicate returns false are discarded. Repeated cases count as accepted inputs. The tester tries up to 100 candidates per requested run and reports how many accepted inputs it found if the budget runs out. It compares results with `refines` and evaluates each `ensures` on the PHP result. `refines` compares arrays and public object fields structurally, with exact integer comparison for `GMP` results. Scalars of different PHP types compare unequal.

A counterexample throws `Conao3\Leanfran\Verify\PropertyFailure` with the function, label, seed, input, implementation result and expected value. A failed postcondition records its false predicate result. If the PHP function throws on an accepted input, the test fails and preserves the throwable, including a `TypeError` from returning an overflowed float through an `int` signature. With only postconditions, this uses the first label and expects a successful return. A float returned to an integer specification also fails the result comparison. Reuse the seed and run count to reproduce the sequence.

For a Lean-enabled CI job, install Composer development dependencies, put `leanfran-php` and the selected Lean toolchain on PATH, and run the proof and property checks. For the clamp sample, run the following from its Composer directory.

```sh
vendor/bin/leanfran check --require proved
php main.php
```

You can run `vendor/bin/leanfran status` in a PHP-only job to check freshness of committed outputs and proof results. Run `check` after editing proof files to refresh their results and enforce the `proved` policy.

## The CLI

`leanfran-php module generate` reads a compiled Lean module and emits PHP source. Run `leanfran-php --help` to see the full usage, including the `obligations check` command used by the Composer CLI. `--version` prints the compiler's release version. `--generator-version` prints the emitted-code version.

| Option | Effect |
| --- | --- |
| `--module-name <Name>` | Selects the compiled Lean module. Required for a single job. |
| `--roots <Name> ...` | Selects the definitions to generate. Defaults to public definitions in the selected module. |
| `--import <Name> ...` | Imports additional Lean modules. |
| `--search-path <dir> ...` | Adds directories to the search path for `.olean` files. |
| `--output-dir <dir>` | Writes PSR-4 public types, a facade, and an internal class. |
| `--php-namespace <NS>` | Sets the PHP namespace. Required with `--output-dir`. |
| `--facade <Name>` | Names the public facade. Defaults to the last component of the module name. |
| `--facade-kind class\|trait` | Emits a facade class or trait. The default is `class`. |
| `--type-module <N=NS>` | Reuses types from Lean namespace `N` that were generated into PHP namespace `NS`. Repeat for multiple namespaces. |
| `--class <NS\Name>` | Sets the PHP class name for single-file output. |
| `--main <Name>` | Generates a CLI entry point for a Lean IO definition in single-file output. |
| `--output-file <path>` | Writes the PHP source to the given file. Defaults to stdout. |
| `--output json\|text` | Sets the summary format. Defaults to JSON. The summary goes to stderr when source goes to stdout. |
| `--internal-only` | Selects the runtime-facing class, also the default without `--output-dir`. |
| `--namespace <Name>` | Removes a Lean namespace prefix from public names. Defaults to the module name. |
| `--batch <file>` | Reads a JSON array of jobs. Each job has `module` and either `output_file` or `output_dir`. Embedding uses public jobs with `php_namespace`, `facade`, `facade_kind`, `type_modules`, and `models`. |

| Exit code | Meaning |
| --- | --- |
| 0 | Success |
| 252 | Invalid arguments, including a missing or unresolved module or an invalid class name |
| 254 | Input that cannot be converted, such as a call to an extern outside the runtime's inventory |
| 255 | Other errors, such as failure to write the output file |

Use `--output-dir` together with `--php-namespace`. Options for single-file output (`--output-file`, `--internal-only`, `--class`, and `--main`) are incompatible with `--output-dir`. The facade and shared-type options apply to directory output. `leanfran-php obligations check --modules … --obligations file` returns JSON states for the supplied obligations. Its exit status indicates whether the command ran successfully. Use the Composer binary's `--require proved` to enforce their states.

## Public types

Generate the public API with `--output-dir` and `--php-namespace`, and map that namespace to the output directory in Composer's PSR-4 autoload configuration. The facade exposes Lean functions as typed static methods. A generation job writes the public types and facade at the root of the output directory and writes the implementation under `Internal/`. The summary lists generated files and skipped definitions with their reasons. Each run removes obsolete files marked as generated by leanfran in those locations.

`--facade` sets the facade name. `--type-module MyApp.Common=App\Lean\Common` refers to types already generated under `App\Lean\Common` with the Lean namespace prefix `MyApp.Common` stripped. Configure Composer to load both output directories. Generated code depends on `conao3/leanfran`.

### PHP and JSON representations

| Lean | Public PHP type | JSON |
| --- | --- | --- |
| `Nat`, `Int` | `int\|\GMP`. Values within PHP's integer range use `int`. | Number |
| `UInt8`, `UInt16`, `UInt32`, `Int8` through `Int64`, `ISize` | `int` with PHPDoc bounds such as `int<0, 255>` | Number |
| `UInt64`, `USize` | Nonnegative `int\|\GMP` | Decimal string |
| `Fin n` | `int` if `n ≤ 2^63`, otherwise `int\|\GMP` | Number |
| `Float`, `Float32` | `float` | Number or a nonfinite value's string |
| `Bool` | `bool` | Boolean |
| `String`, `Char` | UTF-8 `string`. A `Char` has one Unicode scalar. | String |
| `Unit`, `PUnit` | `null` | `{}` |
| `Option α` | The type for `α` or `null` | A value or `null`. A field named `x?` uses key `x` and omits it for `none`. |
| `List α`, `Array α` | `list<T>` | Array |
| `α × β` | `array{0: A, 1: B}` | Two-element array |
| `Except ε α` | `Conao3\Leanfran\Except<E, A>` implemented by `Ok` and `Err` | `{"ok": v}` or `{"error": e}` |
| Structure | Final readonly class with public properties, including flattened parent fields | Object |
| Inductive with only nullary constructors | String-backed enum | Constructor name as a string |
| Other inductives | Interface and one final readonly class per constructor | Externally tagged value |
| Named subtype | Final readonly class with a `val` property | JSON representation of `val` |
| Anonymous subtype | Base PHP type with runtime validation | Base JSON representation |
| Function returning `IO α` | Returns the public type for `α` and throws `Conao3\Leanfran\LeanIOError` on IO errors | Result type's representation |

Parameterized types are generated for each concrete instance used in public signatures. Type names capitalize the first character, join Lean name components with underscores, and append concrete type arguments, as in `PairNatBool`. Facade methods convert each Lean name component to camel case and join the components with underscores. Both naming rules apply after stripping `--namespace`. Constructor classes append the capitalized constructor name, as in `DiscountPercent`. Enum case names capitalize the constructor name. Reserved PHP names gain a trailing underscore, as in `List_`. Case-insensitive collisions gain suffixes such as `_2` and `_3`.

Constructors accept decimal strings for `Nat`, `Int`, `UInt64`, and `USize`, and normalize them to `int` or `\GMP`. Generated constructors validate field types and run the compiled Lean decisions for proof fields and subtype predicates. Proof fields participate in validation and are erased from public properties. Simple bounds also narrow PHPDoc types, for example to `non-empty-string` or `non-empty-list<T>`.

Invalid values raise `Conao3\Leanfran\ValidationError`. Its `issues` contain a `message` and a `path` of field names and array indices for each violation. `getMessage()` formats the first issue as a dotted path and a message, such as `rest.0.Range.ok: lo ≤ hi`. Facade argument issues start with the parameter name.

### JSON

Generated value types provide `fromArray`, `fromJson`, `toArray`, and `toJson`. Externally tagged inductive values use a bare string for nullary constructors and a single-key object for constructors with data. Named parameters produce an object payload, as in `{"percent":{"p":10}}`. Positional parameters use properties such as `a0` in PHP and a single value or an array in JSON, as in `{"positional":6}` and `{"pair":[7,"♥"]}`. Ordinary option fields emit `null` for `none`.

For finite `Float` values, JSON follows Lean's six-place decimal rounding, so `1 / 3` becomes `0.333333` and negative zero becomes `0`. `Float32` uses the same formatting after rounding the value to binary32. The nonfinite values use `"NaN"`, `"Infinity"`, and `"-Infinity"`.

`fromJson()` preserves out-of-range integer literals as `\GMP`. `toJson()` writes large `Nat` and `Int` values as exact number literals, and `UInt64` and `USize` as decimal strings. PHP's `json_encode()` calls `jsonSerialize()`, which emits `\GMP` values as decimal strings. Use `toJson()` for Lean's numeric wire representation.

### JSON Schema

Call `Range::jsonSchema()` to get a schema array for the Lean wire format. Pass `'draft-07'` or `'openapi-3.0'` to choose another target. The default is `'draft-2020-12'`. Other target strings raise `InvalidArgumentException`. Each generated constructor class for an inductive returns the schema for the whole inductive.

The generator follows the TypeScript backend. Recursive definitions use `$defs` in draft 2020-12 and `definitions` in the other targets. Simple bounds become schema keywords such as `maximum` and `minLength`. The generated schema describes the wire shape and expressible bounds. Constructor validation checks relational predicates such as `lo ≤ hi`. Float schemas use `type: number`. The three nonfinite strings are supported by the JSON codec.

The `openapi-3.0` target preserves the TypeScript converter’s tuple and recursion formats. It uses an array of schemas for tuple `items` and local `definitions` for recursion. OpenAPI 3.0 Schema Objects require an object for `items` and specify a fixed set of supported keywords. [OpenAPI 3.0.4 Schema Object](https://spec.openapis.org/oas/v3.0.4.html#schema-object)

### Valinor

Enable Packagist in your application and run `composer require cuyz/valinor:^2.8` to map data directly into the generated constructor signatures. The configured mapper turns a `ValidationError` into a `MappingError` message. Iterate `$error->messages()` to read the mapper's input path and the text of the Lean issue.

```php
$mapper = \Conao3\Leanfran\Valinor::configure(new \CuyZ\Valinor\MapperBuilder())->mapper();
$range = $mapper->map(\App\Lean\Pricing\Range::class, ['lo' => 1, 'hi' => 3]);
```

For an inductive, pass the constructor class to the mapper. Use `fromJson()` or `fromArray()` on a constructor class for externally tagged data. A mapper built without `configure()` propagates Lean's constructor validation exceptions directly.

### Skipped definitions

The public API skips private definitions, polymorphic functions, indexed inductives, type classes, propositions, higher-order signatures, constructors with type-valued fields, and proof fields without a `Decidable` instance. It also skips types with ambiguous nullability such as `Option (Option α)`, library types under `Std`, `Lean`, `IO`, and `System` outside the supported mappings, and runtime-only types such as `ByteArray`, `Thunk`, and `Task`. Read `skipped` in the generation summary for the reason on each definition.

## Runtime-facing class

A job using `--internal-only` emits one PSR-4-compatible PHP file with a `final class`. By default, the class lives in `Leanfran\Generated`. The class name prefixes the module name with `Lean` and joins its components with underscores. `Arith` becomes `LeanArith`, and `Data.List` becomes `LeanData_List`. Module names that need escaping use Lean's identifier mangling.

Roots and reachable definitions, including definitions from imports, are exposed as public static methods. The emitter applies Lean's `Name.mangle` with the prefix `l_`. When two method names would match under case folding, each receives a suffix `__c<hex>`. The suffix encodes which characters in the mangled name are ASCII uppercase. Generation fails with 254 if the final names still collide.

Method signatures follow Lean IR. Boxed and erased values use `mixed`, fixed-width integer scalars use `int`, and floating-point scalars use `float`. Erased and void parameters are omitted. The runtime functions live in `Conao3\Leanfran\Runtime` and Composer loads them automatically.

## Runtime values

| Lean | PHP runtime representation |
| --- | --- |
| `Nat`, `Int` | `int\|\GMP`. Values within the signed 64-bit range use `int`. |
| `UInt8`, `UInt16`, `UInt32` | Nonnegative `int` with arithmetic reduced to the corresponding bit width. |
| `UInt64`, `USize` | An `int` carrying the same 64-bit pattern, including patterns that appear negative in PHP. |
| `Int8` through `Int64`, `ISize` | An `int` carrying the same bits as the corresponding unsigned type. |
| `Bool`, `Char` | `int` for a Boolean tag or Unicode scalar. |
| `Float` | A PHP `float` (binary64). |
| `Float32` | A PHP `float` rounded to binary32. Integer conversions round once at binary32 precision. Transcendental results are within 1 ULP of the native oracle. |
| `String` | `LString` holding validated UTF-8. Positions are byte offsets. Length counts Unicode scalars. |
| `Array α` | `LArray` holding a zero-based PHP array of Lean runtime values. |
| `ByteArray`, `FloatArray` | `LByteArray` holding a byte string and `LFloatArray` holding PHP floats. |

## IO and tasks

`--main` emits `runMain` and runs it when PHP executes the generated file directly. Module initializers run in declaration order before the entry point. A failure in initialization stops execution. The runtime writes uncaught IO errors to stderr as `uncaught exception: …` and exits with status 1.

The runtime supports stdin, stdout, stderr, file and directory operations, clocks, environment variables, and child processes. It drains both output pipes when reading from a child with piped stdout and stderr. Monotonic time comes from `hrtime` in nanoseconds or whole milliseconds. Wall-clock time has microsecond precision and is returned in seconds and nanoseconds. File access and modification timestamps have one-second precision. On Unix, process spawning with `setsid` requires the PHP `posix` and `pcntl` extensions. PHP's `exit` implements `IO.Process.forceExit`, so PHP shutdown handlers still run.

Tasks started with spawn, map, bind, or `IO.asTask` run synchronously and return a completed task. Priority and cancellation have no effect. Waiting on an unresolved `IO.Promise` panics.

## Recursion and PHP settings

Self tail calls use jumps. Mutual tail calls and tail calls through closures use a trampoline. The depth tests run one million steps under `memory_limit=128M`. For non-tail recursion, the practical limit depends on PHP's `memory_limit` and, with Xdebug enabled, `xdebug.max_nesting_level`.

OPcache and JIT are optional runtime settings. If Zend OPcache is loaded, set `opcache.enable_cli=1` to enable it for CLI processes. Set `opcache.jit=tracing` and a nonzero `opcache.jit_buffer_size` to enable tracing JIT. Run the quick-start application with these settings.

```sh
php -d opcache.enable_cli=1 -d opcache.jit=tracing -d opcache.jit_buffer_size=64M main.php
```

## Backend testing

The [development checks](php-development.md#verification) run on PHP 8.4 and 8.5. They compare stdout, stderr, and exit status against Lean's C backend and also compare filesystem changes for 11 IO fixtures. The default fuzz run compares 2,026 inputs with the C backend, including 2,000 seeded random rows.

The numeric test covers 427 extern declarations with 402 distinct C symbols. Its 423 call cases use products of boundary values and 2,000 seeded random inputs per case. The PHP 8.4 and 8.5 checks on x86-64 Linux each matched 1,707,520 numeric results byte for byte, 65 within 1 ULP, and 1,456 expected panic outputs byte for byte. The 1 ULP allowance applies to Float32 transcendental functions and binary64 `exp2` and `log2`.

## Planned features

- Publish the Composer package on Packagist.
- Call proved PHP functions from generated PHP code.
