# Run the targets inside the dev shell: `nix develop -c make check`.

.PHONY: build gen-externs test format format-check bench check

build:
	lake build lean-python oracle oracle-io oracle-json oracle-bench LeanPythonTest
	uv sync -q

gen-externs:
	uv run python scripts/gen_externs.py > LeanPython/RuntimeExterns.lean.tmp
	mv LeanPython/RuntimeExterns.lean.tmp LeanPython/RuntimeExterns.lean

test: build
	./test-diff.sh
	uv run pytest -q

format:
	treefmt

format-check:
	treefmt --ci

bench: build
	uv run python samples/bench/bench.py

check: format-check test
