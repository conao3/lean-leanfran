# Building checks the lean! blocks with Lean when .lean-rust/cache/ has no entry for them; the
# lean-rust CLI of the repository is used then.
export LEAN_RUST_CLI := $(abspath ../../../.lake/build/bin/lean-rust)

.PHONY: all
all: test

.PHONY: lean-rust
lean-rust:
	cd ../../.. && lake build lean-rust

.PHONY: test
test: lean-rust
	cargo test -q -p step-08-polymorphic
