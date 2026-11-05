#!/usr/bin/env bash
# Run verified.main and compare its output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp)
clojure -M -m verified.main > "$out"
diff -u expected.txt "$out"
echo "verified-clojure: output matches expected.txt"
