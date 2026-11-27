export LEANFRAN_CLI := $(abspath ../../../../.lake/build/bin/leanfran)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	$(MAKE) -C ../.. build

.PHONY: run
run: leanfran
	./todo $(ARGS)

.PHONY: test
test: leanfran
	./test.sh
