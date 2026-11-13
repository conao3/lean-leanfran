# `make test` builds from the committed caches and runs the tests: no Lean, Charon or Aeneas.
# `make verify` extracts the model and checks the proofs again (inside the repository's
# `nix develop`, with Mathlib in ../../../.lake-aeneas/packages) and fails when the committed
# model, obligations, csimp or lockfile are not up to date.
export LEANFRAN_CLI := $(abspath ../../../.lake/build/bin/leanfran)
CARGO_LEANFRAN := $(abspath ../../../target/debug/cargo-leanfran)

.PHONY: all
all: test

.PHONY: test
test:
	cargo test -q -p step-11-prop-specs

.PHONY: tools
tools:
	cd ../../.. && lake build leanfran && cargo build -q -p cargo-leanfran

.PHONY: verify
verify: tools
	$(CARGO_LEANFRAN) leanfran extract
	$(CARGO_LEANFRAN) leanfran check
	git diff --exit-code -- lean/LeanRustGen leanfran.lock
