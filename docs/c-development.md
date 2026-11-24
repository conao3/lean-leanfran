# C development

The C backend builds on Lean's native C emitter and runtime. It selects Lean definitions, generates a public C API and builds the library and its link settings.

## Layout

- `langs/C/Main.lean` parses `leanfran-c generate` and `build`.
- `langs/C/LeanC/Export.lean` selects declarations and emits the Lean export module. Its `@[export]` declarations supply stable symbols independent of the Lake package name.
- `langs/C/LeanC/Check.lean` inspects reachable declarations and imports for `sorryAx`, compiler dependencies, externs, and `implemented_by` replacements.
- `langs/C/LeanC/Header.lean` emits the C11 header, conversion wrappers, and per-module initializer. `langs/C/support/` provides the common ABI, runtime initialization, and string and error ownership helpers.
- `langs/C/LeanC/Build.lean` uses Lake's module dependencies and native objects to assemble the library. `langs/C/LeanC/Link.lean` uses the active toolchain's `leanc --print-ldflags` output to generate pkg-config, Make, and CMake settings. Linux groups the static Lean libraries for the linker. macOS links them without GNU linker groups.
- `langs/C/tests/cases/` is a Lake workspace with the Lean fixtures and native oracle. `langs/C/tests/link/` holds the C consumers and build fixtures. `maint/C/test-diff.sh` and `maint/C/test-link.sh` drive the checks.

When changing wrappers, inspect the pinned Lean toolchain's generated C and `lean.h` for the exact ABI and ownership conventions. Keep the public header usable from C11 and C++ and keep the Lean runtime types inside the implementation.

## Verification

Run from the repository root.

```sh
nix shell nixpkgs#gnumake -c make format BACKENDS=C
nix shell nixpkgs#gnumake -c make check BACKENDS=C
nix build .#c
```

CI builds the Nix package and runs the C checks on Linux and macOS arm64. To run the macOS check directly in the C shell, use `nix develop .#c -c make -C langs/C check`.

The differential check compares stdout, stderr, and process status with the native Lean oracle for successful and failing I/O. It tests calls before initialization, repeat and concurrent initialization, and initialization errors. To detect ownership errors in Lean objects, it counts live mimalloc blocks across repeated calls and checks that intentionally missing or extra decrements change the count. Linux also runs ASan, LeakSanitizer, and UBSan on the C conversion and support code.

The link check exercises generation diagnostics, user-supplied externs, and compiler imports. It builds the generated wrappers as C11 and checks the public header from C++17. Fixtures compile and run consumers through pkg-config, GNU Make, and CMake with static and shared libraries.
