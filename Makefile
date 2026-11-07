# Run the targets inside the dev shell: `nix develop -c make check`.

.PHONY: build gen-externs test format format-check lint check

build:
	lake build lean-rust oracle LeanRustTest
	cargo build --workspace --exclude lean-rust-difftest

gen-externs:
	cargo run -q -p lean-rust-runtime --example gen-externs > LeanRust/RuntimeExterns.lean.tmp
	mv LeanRust/RuntimeExterns.lean.tmp LeanRust/RuntimeExterns.lean

test:
	lake build
	./test-diff.sh
	cargo nextest run -p lean-rust-runtime

format:
	treefmt

format-check:
	treefmt --ci

lint:
	cargo clippy -p lean-rust-runtime --all-targets -- -D warnings

check: format-check lint test
