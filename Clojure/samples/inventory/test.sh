#!/usr/bin/env bash
# Run inventory.main and compare its output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp)
clojure -M -m inventory.main > "$out"
diff -u expected.txt "$out"
echo "inventory: output matches expected.txt"
