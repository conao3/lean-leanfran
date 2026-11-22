# PHP guide

[leanfran](../README.md) · [PHP quick start](../langs/PHP/README.md) · [Samples](../langs/PHP/samples/README.md)

## Installation

Generation uses Lean 4.35.0 and the `leanfran-php` compiler. Follow the [quick start](../langs/PHP/README.md) to build the compiler with Nix and install the runtime from a Composer path repository. Running the generated code requires 64-bit PHP 8.4 or later and `ext-gmp`.

## The CLI

`leanfran-php module generate` reads a compiled Lean module and emits a PHP class. Run `leanfran-php help` to see the full usage. `--version` prints the compiler's release version. `--generator-version` prints the emitted-code version.

| Option | Effect |
| --- | --- |
| `--module-name <Name>` | Selects the compiled Lean module. Required for a single job. |
| `--roots <Name> ...` | Selects the definitions to generate. Defaults to public definitions in the selected module. |
| `--import <Name> ...` | Imports additional Lean modules. |
| `--search-path <dir> ...` | Adds directories to the search path for `.olean` files. |
| `--class <NS\Name>` | Sets the fully qualified PHP class name. |
| `--main <Name>` | Generates a CLI entry point for a Lean IO definition. |
| `--output-file <path>` | Writes the PHP source to the given file. Defaults to stdout. |
| `--output json\|text` | Sets the summary format. Defaults to JSON. The summary goes to stderr when source goes to stdout. |
| `--internal-only` | Requests the runtime-facing class. |
| `--namespace <Name>` | Reserved for public wrappers. Use `--class` to set the generated PHP namespace. |
| `--batch <file>` | Reads a JSON array of jobs. Each job has `module` and `output_file` and may have `roots`, `namespace`, `class`, and `main`. Supply the per-job settings in the file. |

| Exit code | Meaning |
| --- | --- |
| 0 | Success |
| 252 | Invalid arguments, including a missing module or invalid class name |
| 254 | Input that cannot be converted, such as a call to an extern outside the runtime's inventory |
| 255 | Other errors, such as failure to write the output file |

## Generated classes

A generation job emits one PSR-4-compatible PHP file with a `final class`. By default, the class lives in `Leanfran\Generated`. The class name prefixes the module name with `Lean` and joins its components with underscores. `Arith` becomes `LeanArith`, and `Data.List` becomes `LeanData_List`. Module names that need escaping use Lean's identifier mangling.

Roots and reachable definitions, including definitions from imports, are exposed as public static methods. The emitter applies Lean's `Name.mangle` with the prefix `l_`. When two method names would match under case folding, each receives a suffix `__c<hex>`. The suffix encodes which characters in the mangled name are ASCII uppercase. Generation fails with 254 if the final names still collide.

Method signatures follow Lean IR. Boxed and erased values use `mixed`, fixed-width integer scalars use `int`, and floating-point scalars use `float`. Erased and void parameters are omitted. The runtime functions live in `Conao3\Leanfran\Runtime` and Composer loads them automatically.

## Values

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

## Verification

The [development checks](php-development.md#verification) run on PHP 8.4 and 8.5. They compare stdout, stderr, and exit status against Lean's C backend and also compare filesystem changes for 11 IO fixtures. The default fuzz run compares 2,026 inputs with the C backend, including 2,000 seeded random rows.

The numeric test covers 427 extern declarations with 402 distinct C symbols. Its 423 call cases use products of boundary values and 2,000 seeded random inputs per case. The PHP 8.4 and 8.5 checks on x86-64 Linux each matched 1,707,520 numeric results byte for byte, 65 within 1 ULP, and 1,456 expected panic outputs byte for byte. The 1 ULP allowance applies to Float32 transcendental functions and binary64 `exp2` and `log2`.

## Planned features

Public type and function wrappers, embedded Lean blocks in PHP, and verification of PHP functions against Lean specifications are planned for later stages.
