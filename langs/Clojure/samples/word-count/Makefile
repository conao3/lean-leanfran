LEANFRAN_CLJ_BIN := $(abspath ../../.lake/build/bin)
export PATH := $(LEANFRAN_CLJ_BIN):$(PATH)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	$(MAKE) -C ../.. build

.PHONY: run
run: leanfran
	./word-count text list-top-words $(ARGS) < sample.txt

.PHONY: test
test: leanfran
	./test.sh
