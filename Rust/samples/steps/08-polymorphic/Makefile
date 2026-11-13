# Building checks the lean! blocks with Lean when .leanfran/cache/ has no entry for them; the
# leanfran CLI of the repository is used then.
export LEANFRAN_CLI := $(abspath ../../../.lake/build/bin/leanfran)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	cd ../../.. && lake build leanfran

.PHONY: test
test: leanfran
	cargo test -q -p step-08-polymorphic
