# Run the targets inside the dev shell: `nix develop -c make check`.

.PHONY: build gen-externs test samples format format-check bench check

build:
	lake build lean-python oracle oracle-io oracle-json oracle-bench LeanPythonTest
	uv sync -q

gen-externs:
	uv run python scripts/gen_externs.py > LeanPython/RuntimeExterns.lean.tmp
	mv LeanPython/RuntimeExterns.lean.tmp LeanPython/RuntimeExterns.lean

test: build
	./test-diff.sh
	uv run pytest -q

# Sync, run and compare every sample; the committed generated modules must be up to date.
samples: build
	for s in samples/*/ samples/steps/*/; do [ -f $$s/expected.txt ] || continue; LEAN_PYTHON_CLI=$(CURDIR)/.lake/build/bin/lean-python samples/run.sh $$s || exit 1; done
	git diff --exit-code -- samples

format:
	treefmt

format-check:
	treefmt --ci

bench: build
	uv run python samples/bench/bench.py

check: format-check test samples
