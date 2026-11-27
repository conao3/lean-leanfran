# Add a language

Add support for the language requested by the contributor to leanfran.

Read `AGENTS.md`, `CONTRIBUTING.md` and the existing backend development guides first.
For a backend that translates Lean IR, follow the existing emitters and
host-language runtimes. Match Lean's runtime semantics and extern conventions.
Give the backend a Lake project under `langs/<LANGUAGE>/` for its tests and oracles, and
compare its public calls with the native Lean oracle. Put its command line in the module
`Lean<X>.Cli`, add its library to the root `lakefile.toml` and to the `leanfran` package of
`flake.nix`, and add its `--lang` value to the root `Main.lean` and to
`maint/test-compiler.sh`. Add host-language tests, runnable examples
and documentation covering setup, usage and supported features.

A backend that uses Lean's native emitter and runtime should exercise the API
and build integration it supplies. See the [C development guide](c-development.md)
for checks covering wrappers, initialization, ownership and linking.

Integrate the backend into the shared Nix environment, root Makefile and CI. Add
the backend and its development guide to `CONTRIBUTING.md` and update the
repository layout in `AGENTS.md`.
List the language in the root README: the registry badge in the header, the
language and documentation tables, and the install notes in Get started.
Run the relevant build, test and formatting checks, and report their results
along with any remaining limitations for review.
