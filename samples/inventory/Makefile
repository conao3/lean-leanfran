# `make test` builds from the committed caches and runs the tests: no Lean, Charon or Aeneas.
# `make verify` extracts the models and checks the proofs again (inside the repository's
# `nix develop`, with Mathlib in ../../.lake-aeneas/packages) and fails when the committed
# model, obligations, csimp or lockfile are not up to date.
export LEAN_RUST_CLI := $(abspath ../../.lake/build/bin/lean-rust)
CARGO_LEAN_RUST := $(abspath ../../target/debug/cargo-lean-rust)

.PHONY: all
all: test

.PHONY: test
test:
	cargo test -q -p inventory

.PHONY: tools
tools:
	cd ../.. && lake build lean-rust && cargo build -q -p cargo-lean-rust

.PHONY: verify
verify: tools
	$(CARGO_LEAN_RUST) lean-rust extract
	$(CARGO_LEAN_RUST) lean-rust check
	git diff --exit-code -- lean/LeanRustGen lean-rust.lock
