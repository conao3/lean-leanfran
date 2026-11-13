#!/usr/bin/env bash
# Generate the public API of LeanRustTest.Public and run the Rust tests that call it.
set -euo pipefail
cd "$(dirname "$0")/../../langs/Rust"
lake build leanfran LeanRustTest
mkdir -p test-out
.lake/build/bin/leanfran module generate \
  --module-name LeanRustTest.Public \
  --search-path .lake/build/lib/lean \
  --output-file test-out/public.rs --output text
cargo nextest run -p leanfran-public-test
