# Run the targets inside the dev shell: `nix develop -c make check`.

.PHONY: build gen-externs test format format-check lint check

build:
	lake build lean-rust oracle LeanRustTest
	cargo build --workspace --exclude lean-rust-difftest --exclude lean-rust-public-test

gen-externs:
	cargo run -q -p lean-rust-runtime --example gen-externs > LeanRust/RuntimeExterns.lean.tmp
	mv LeanRust/RuntimeExterns.lean.tmp LeanRust/RuntimeExterns.lean

test:
	lake build
	./test-diff.sh
	./test-public.sh
	LEAN_RUST_CLI=$(CURDIR)/.lake/build/bin/lean-rust cargo nextest run -p lean-rust-runtime -p lean-rust-build -p lean-rust-embed-test
	tests/embed/test.sh
	$(MAKE) -C samples test

format:
	treefmt

format-check:
	treefmt --ci

lint:
	cargo clippy -p lean-rust-runtime -p lean-rust -p lean-rust-macros -p lean-rust-build -p lean-rust-embed-test -p todo-cli -p word-count -p roman-numerals --all-targets -- -D warnings

check: format-check lint test
