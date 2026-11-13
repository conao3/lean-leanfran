# Run the targets inside the dev shell: `nix develop ..#rust -c make check`.

.PHONY: build gen-externs test format format-check lint wasm check aeneas-packages check-verify

build:
	lake build leanfran oracle LeanRustTest
	cargo build --workspace --exclude leanfran-difftest --exclude leanfran-public-test

gen-externs:
	cargo run -q -p leanfran-runtime --example gen-externs > LeanRust/RuntimeExterns.lean.tmp
	mv LeanRust/RuntimeExterns.lean.tmp LeanRust/RuntimeExterns.lean

test:
	lake build
	../maint/Rust/test-diff.sh
	../maint/Rust/test-public.sh
	LEANFRAN_CLI=$(CURDIR)/.lake/build/bin/leanfran cargo nextest run -p leanfran-runtime -p leanfran-build -p leanfran-embed-test -p leanfran-verify-test -p leanfran-wasm-test
	tests/embed/test.sh
	$(MAKE) -C samples test

format:
	treefmt

format-check:
	treefmt --ci

lint:
	cargo clippy -p leanfran-runtime -p leanfran -p leanfran-macros -p leanfran-build -p cargo-leanfran -p leanfran-embed-test -p leanfran-verify-test -p leanfran-wasm-test -p todo-cli -p word-count -p roman-numerals -p verified-rust -p sorted-search -p inventory -p generic-search -p step-01-functions -p step-02-theorems -p step-03-structures -p step-04-inductives -p step-05-collections -p step-06-imports -p step-07-io -p step-08-polymorphic -p step-09-lake-project -p step-10-ensures -p step-11-prop-specs -p step-12-requires -p step-13-refines -p step-14-loops -p step-15-structs-enums -p step-16-opaque -p step-17-generics --all-targets -- -D warnings

# The runtime and generated code on wasm32-unknown-unknown, run in node.
wasm:
	cargo clippy -p leanfran-runtime -p leanfran --no-default-features --target wasm32-unknown-unknown -- -D warnings
	tests/wasm/test.sh

check: format-check lint wasm test

# Lake's packages of the Lean packages of tests/verify and samples/ (Aeneas, Mathlib and its
# build cache, 7.9 GB), shared through their `packagesDir`.
aeneas-packages:
	cd samples/verified-rust/lean && lake exe cache get

# Extraction and proof checking with Charon, Aeneas and Mathlib.
check-verify: aeneas-packages
	lake build leanfran
	tests/verify/test.sh
	$(MAKE) -C samples verify
