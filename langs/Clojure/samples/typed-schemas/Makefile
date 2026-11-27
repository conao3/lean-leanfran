export LEANFRAN_CLI := $(abspath ../../../../.lake/build/bin/leanfran)

.PHONY: all
all: test

.PHONY: leanfran
leanfran:
	$(MAKE) -C ../.. build

# Regenerate .clj-kondo/leanfran/types/config.edn from the signatures.
.PHONY: kondo-config
kondo-config: leanfran
	clojure -M -e "(require 'accounts.core 'leanfran.types) (leanfran.types/write-kondo-config! ['accounts.core])"

.PHONY: run
run: leanfran
	clojure -M -m accounts.main

.PHONY: test
test: kondo-config
	git diff --exit-code -- .clj-kondo/leanfran/types/config.edn
	./test.sh
