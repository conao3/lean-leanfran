# Run the targets inside the dev shell: `nix develop -c make check`.

.PHONY: build gen-externs test format format-check lint check aeneas-packages check-verify

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
	LEAN_RUST_CLI=$(CURDIR)/.lake/build/bin/lean-rust cargo nextest run -p lean-rust-runtime -p lean-rust-build -p lean-rust-embed-test -p lean-rust-verify-test
	tests/embed/test.sh
	$(MAKE) -C samples test

format:
	treefmt

format-check:
	treefmt --ci

lint:
	cargo clippy -p lean-rust-runtime -p lean-rust -p lean-rust-macros -p lean-rust-build -p cargo-lean-rust -p lean-rust-embed-test -p lean-rust-verify-test -p todo-cli -p word-count -p roman-numerals -p verified-rust -p sorted-search -p inventory -p generic-search -p step-01-functions -p step-02-theorems -p step-03-structures -p step-04-inductives -p step-05-collections -p step-06-imports -p step-07-io -p step-08-polymorphic -p step-09-lake-project -p step-10-ensures -p step-11-prop-specs -p step-12-requires -p step-13-refines -p step-14-loops -p step-15-structs-enums -p step-16-opaque -p step-17-generics --all-targets -- -D warnings

check: format-check lint test

# Lake's packages of the Lean packages of tests/verify and samples/ (Aeneas, Mathlib and its
# build cache, 7.9 GB), shared through their `packagesDir`.
aeneas-packages:
	cd samples/verified-rust/lean && lake exe cache get

# Extraction and proof checking with Charon, Aeneas and Mathlib.
check-verify: aeneas-packages
	lake build lean-rust
	tests/verify/test.sh
	$(MAKE) -C samples verify
