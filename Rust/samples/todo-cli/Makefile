# Building checks the lean! block with Lean when .leanfran/cache/ has no entry for it; the
# leanfran CLI of the repository is used then.
export LEANFRAN_CLI := $(abspath ../../.lake/build/bin/leanfran)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	cd ../.. && lake build leanfran

.PHONY: run
run: leanfran
	cargo run -q -p todo-cli -- $(ARGS)

.PHONY: test
test: leanfran
	./test.sh
