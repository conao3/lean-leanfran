LEAN_CLJ_BIN := $(abspath ../../.lake/build/bin)
export PATH := $(LEAN_CLJ_BIN):$(PATH)

.PHONY: all
all: test

.PHONY: lean-clj
lean-clj:
	$(MAKE) -C ../.. build

.PHONY: run
run: lean-clj
	clojure -M -m verified.main

.PHONY: test
test: lean-clj
	./test.sh
