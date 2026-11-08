#!/usr/bin/env bash
# Call the generated Rust functions and compare with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
cargo build -q -p roman-numerals
bin=../../target/debug/roman-numerals
{
  "$bin" to-roman 1994
  "$bin" from-roman MMXXVI
  "$bin" from-roman hello 2>&1 || echo "exit $?"
  for n in 1 2 3 4 5 6 7 8 9 10; do "$bin" to-roman "$n"; done | paste -sd' '
} | diff -u expected.txt -
echo "roman-numerals: output matches expected.txt"
