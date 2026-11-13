#!/usr/bin/env bash
# Diff-test: run LeanRustTest.Vectors.report and LeanRustTest.Io.run on the native C
# backend and on the generated Rust, and compare stdout and stderr.
set -euo pipefail
cd "$(dirname "$0")/../../langs/Rust"
ulimit -s 65536
export LEAN_BACKTRACE=0
export LEANFRAN_TEST_VAR=from-the-environment
lake build leanfran oracle oracle-io LeanRustTest
mkdir -p test-out
generate() {
  .lake/build/bin/leanfran module generate \
    --module-name "$1" --roots "$2" \
    --search-path .lake/build/lib/lean --runtime-path ::leanfran_runtime \
    --output-file "$3" --output text --internal-only
}
generate LeanRustTest.Vectors LeanRustTest.Vectors.report test-out/vectors.rs
generate LeanRustTest.Io LeanRustTest.Io.run test-out/io.rs
.lake/build/bin/oracle > test-out/oracle.txt 2> test-out/oracle.err
.lake/build/bin/oracle-io < /dev/null > test-out/io-oracle.txt 2> test-out/io-oracle.err
cargo build -q --release -p leanfran-difftest
target/release/leanfran-difftest > test-out/rust.txt 2> test-out/rust.err
target/release/leanfran-difftest-io < /dev/null > test-out/io-rust.txt 2> test-out/io-rust.err
diff -u test-out/oracle.txt test-out/rust.txt
diff -u test-out/oracle.err test-out/rust.err
diff -u test-out/io-oracle.txt test-out/io-rust.txt
diff -u test-out/io-oracle.err test-out/io-rust.err
echo "diff-test: $(wc -l < test-out/oracle.txt) + $(wc -l < test-out/io-oracle.txt) lines match"
