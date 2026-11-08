#!/usr/bin/env bash
# Count the words of sample.txt and compare with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
cargo build -q -p word-count
../../target/debug/word-count text list-top-words --limit 4 < sample.txt | diff -u expected.txt -
echo "word-count: output matches expected.txt"
