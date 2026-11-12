LEAN_CLJ_BIN := $(abspath ../../.lake/build/bin)
export PATH := $(LEAN_CLJ_BIN):$(PATH)

.PHONY: all
all: test

.PHONY: lean-clj
lean-clj:
	$(MAKE) -C ../.. build

# Regenerate .clj-kondo/lean-clj/types/config.edn from the signatures.
.PHONY: kondo-config
kondo-config: lean-clj
	clojure -M -e "(require 'accounts.core 'lean-clj.types) (lean-clj.types/write-kondo-config! ['accounts.core])"

.PHONY: run
run: lean-clj
	clojure -M -m accounts.main

.PHONY: test
test: kondo-config
	git diff --exit-code -- .clj-kondo/lean-clj/types/config.edn
	./test.sh
