export LEANFRAN_CLI := $(abspath ../../../../.lake/build/bin/leanfran)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	$(MAKE) -C ../.. build

.PHONY: run
run: leanfran
	clojure -M -m verified.main

.PHONY: test
test: leanfran
	./test.sh
