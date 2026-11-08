LEAN_RUST := ../../../.lake/build/bin/lean-rust

.PHONY: all
all: test

.PHONY: lean-rust
lean-rust:
	cd ../../.. && lake build lean-rust

# Check the Lean library (proofs included) and regenerate src/generated/.
.PHONY: generate
generate: lean-rust
	$(LEAN_RUST) project generate --lake-dir lean --output-dir src/generated --output text
	rustfmt --edition 2021 src/generated/mod.rs

.PHONY: test
test: generate
	git diff --exit-code -- src/generated
	cargo test -q -p step-09-lake-project
