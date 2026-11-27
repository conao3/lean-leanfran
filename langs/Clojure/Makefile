export LEANFRAN_CLI := $(abspath ../../.lake/build/bin/leanfran)

.PHONY: all
all: build

.PHONY: build
build:
	lake --dir ../.. build leanfran

.PHONY: format
format:
	treefmt
	cljstyle fix src test resources samples

.PHONY: format-check
format-check:
	treefmt --ci
	cljstyle check src test resources samples

.PHONY: lint
lint:
	clj-kondo --lint src test resources samples/todo-cli/src samples/word-count/src samples/verified-clojure/src samples/sorted-search/src samples/typed-schemas/src samples/inventory/src samples/generic-search/src

.PHONY: test
test: build
	../../maint/Clojure/test-diff.sh
	clojure -M:test
	$(MAKE) -C samples test

.PHONY: test-generate
test-generate: build
	../../maint/test-generate.sh ../../.lake/build/bin/leanfran clojure

.PHONY: check
check: format-check lint test test-generate

.PHONY: jar
jar:
	clojure -T:build jar

.PHONY: deploy
deploy:
	clojure -T:build deploy
