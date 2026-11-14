# Add a language

Add support for the language requested by the contributor to leanfran.

Read `AGENTS.md`, `CONTRIBUTING.md` and the existing backend development guides first.
Follow the existing backends to implement a Lean IR emitter, a host-language
runtime and an idiomatic package under `langs/<LANGUAGE>/`. Match Lean's runtime
semantics and extern conventions, and compare generated programs against Lean's
native C backend with differential tests. Add host-language tests, runnable
examples and documentation covering setup, usage and supported features.

Integrate the backend into the shared Nix environment, root Makefile and CI.
Run the relevant build, test and formatting checks, and report their results
along with any remaining limitations for review.
