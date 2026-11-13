#!/usr/bin/env bash
# Run generic.main and compare its output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp)
clojure -M -m generic.main > "$out"
diff -u expected.txt "$out"
echo "generic-search: output matches expected.txt"
