LEANFRAN := ../../../.lake/build/bin/leanfran

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	cd ../../.. && lake build leanfran

# Check the Lean library (proofs included) and regenerate src/generated/.
.PHONY: generate
generate: leanfran
	$(LEANFRAN) project generate --lake-dir lean --output-dir src/generated --output text
	rustfmt --edition 2021 src/generated/mod.rs

.PHONY: test
test: generate
	git diff --exit-code -- src/generated
	cargo test -q -p step-09-lake-project
