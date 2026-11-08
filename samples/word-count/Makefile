# Building checks the lean! block with Lean when .lean-rust/cache/ has no entry for it; the
# lean-rust CLI of the repository is used then.
export LEAN_RUST_CLI := $(abspath ../../.lake/build/bin/lean-rust)

.PHONY: all
all: test

.PHONY: lean-rust
lean-rust:
	cd ../.. && lake build lean-rust

.PHONY: run
run: lean-rust
	cargo run -q -p word-count -- text list-top-words $(ARGS) < sample.txt

.PHONY: test
test: lean-rust
	./test.sh
