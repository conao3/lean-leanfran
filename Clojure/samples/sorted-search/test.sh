#!/usr/bin/env bash
# Run search.main and compare its output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp)
clojure -M -m search.main > "$out"
diff -u expected.txt "$out"
echo "sorted-search: output matches expected.txt"
