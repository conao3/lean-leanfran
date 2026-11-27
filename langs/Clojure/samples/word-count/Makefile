export LEANFRAN_CLI := $(abspath ../../../../.lake/build/bin/leanfran)

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
