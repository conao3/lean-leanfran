#!/usr/bin/env bash
# Sync the Lean blocks of a sample, run it, and compare its output with expected.txt.
# usage: samples/run.sh <sample dir>   (LEAN_PYTHON_CLI points at the built lean-python)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dir=$(cd "$1" && pwd)
pkg=$(basename "$(find "$dir" -mindepth 2 -maxdepth 2 -name __init__.py -not -path '*/_lean/*' | head -1 | xargs dirname)")
cd "$dir"
uv run --project "$root" lean-py sync --package "$pkg" 2> sync.log || { cat sync.log; exit 1; }
if [ -x ./run-sample.sh ]; then
  ./run-sample.sh > out.txt 2> err.txt || { cat err.txt; exit 1; }
else
  PYTHONPATH="$dir" uv run --project "$root" python -m "$pkg" > out.txt 2> err.txt || { cat err.txt; exit 1; }
fi
diff -u expected.txt out.txt
rm -f out.txt err.txt sync.log
echo "$(basename "$dir"): output matches expected.txt"
