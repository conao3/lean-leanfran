#!/usr/bin/env bash
# Diff-test: run LeanRustTest.Vectors.report on the native C backend and on the
# generated Rust, and compare the output.
set -euo pipefail
ulimit -s 65536
export LEAN_BACKTRACE=0
lake build lean-rust oracle LeanRustTest
mkdir -p test-out
.lake/build/bin/lean-rust module generate \
  --module-name LeanRustTest.Vectors --roots LeanRustTest.Vectors.report \
  --search-path .lake/build/lib/lean --runtime-path ::lean_rust_runtime \
  --output-file test-out/vectors.rs --output text
.lake/build/bin/oracle > test-out/oracle.txt 2> test-out/oracle.err
cargo build -q --release -p lean-rust-difftest
target/release/lean-rust-difftest > test-out/rust.txt 2> test-out/rust.err
diff -u test-out/oracle.txt test-out/rust.txt
diff -u test-out/oracle.err test-out/rust.err
echo "diff-test: $(wc -l < test-out/oracle.txt) lines match"
