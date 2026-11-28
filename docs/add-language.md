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

To embed Lean blocks in host-language sources, join `leanfran --lang <language> sync`,
`check` and `status`. `Leanfran.Embed` (`Leanfran/Embed/`) runs them for every language: it
writes the Lake workspace in `.leanfran/<language>/workspace`, builds the blocks, maps Lean
errors to the host source, generates and installs the files, and writes
`leanfran.manifest.json` and `leanfran.lock`. The backend supplies two things:

- A `Leanfran.Embed.Backend` value in `Lean<X>/Embed.lean`. It names the language and its
  directory option, launches the language package, and gives the workspace `lakefile.toml`,
  the Lean support modules and the headers of generated files. `Lean<X>.Cli` passes `sync`,
  `check` and `status` with this value to `Leanfran.Embed.run`.
- The commands `scan` and `translate` of the language package. `scan --root <root> --dir
  <dir>` reads the project's sources and prints the blocks, their source positions and
  hashes, and the functions to verify as one JSON object. `translate --root <root>` reads
  that result and the generation summaries from standard input and prints the Lean
  translation of the functions. Both run in the project root, write no files, compare
  `LEANFRAN_VERSION`, `LEANFRAN_GENERATOR_VERSION` and `LEANFRAN_LEAN_VERSION` with the
  package's own constants, and exit with 0, with 254 for an error in the project
  (`<file>:<line>:<column>: <message>` on standard error), or with 255 for an error in the
  environment.

The Go backend is the example: `langs/Go/LeanGo/Embed.lean` holds its `Backend`, and
`langs/Go/cmd/leanfran-go/` holds `scan` and `translate`. `maint/test-embed.sh` runs the
shared flow with the fake package `tests/embed/fake.sh`; the `scan` and `translate` results
that the script writes for it show the JSON that the two commands exchange with the compiler.

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
