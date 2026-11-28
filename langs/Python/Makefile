# Run the targets inside the dev shell: `nix develop ../..#python -c make check`.

.PHONY: build gen-externs test test-generate samples format format-check bench check

build:
	lake --dir ../.. build leanfran
	lake build oracle oracle-io oracle-json oracle-bench LeanPythonTest
	uv sync -q

gen-externs:
	uv run python ../../maint/Python/gen_externs.py > LeanPython/RuntimeExterns.lean.tmp
	mv LeanPython/RuntimeExterns.lean.tmp LeanPython/RuntimeExterns.lean

test: build
	../../maint/Python/test-diff.sh
	uv run pytest -q

test-generate: build
	../../maint/test-generate.sh ../../.lake/build/bin/leanfran python

# Check the committed samples with status, then sync, run and compare every sample.
samples: build
	../../maint/Python/test-samples.sh

format:
	treefmt

format-check:
	treefmt --ci

bench: build
	uv run python samples/bench/bench.py

check: format-check test samples test-generate
