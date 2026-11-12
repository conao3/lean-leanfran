#!/usr/bin/env bash
# Run accounts.main and lint examples/misuse.clj with the generated clj-kondo
# types, and compare the output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp)
{
  clojure -M -m accounts.main
  clj-kondo --lint examples/misuse.clj | grep -v "^linting took" || true
} > "$out"
diff -u expected.txt "$out"
echo "typed-schemas: output matches expected.txt"
