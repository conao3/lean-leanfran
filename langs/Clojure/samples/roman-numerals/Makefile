LEANFRAN_CLJ := ../../.lake/build/bin/leanfran

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	$(MAKE) -C ../.. build

# Check the Lean library (proofs included) and regenerate src/roman/core.clj.
.PHONY: generate
generate: leanfran
	cd lean && lake build
	$(LEANFRAN_CLJ) module generate-namespace --module-name Roman --namespace roman.core \
	  --search-path lean/.lake/build/lib/lean --output-file src/roman/core.clj --output text
	cljstyle fix src/roman/core.clj

.PHONY: test
test: generate
	git diff --exit-code -- src/roman/core.clj
	./test.sh
