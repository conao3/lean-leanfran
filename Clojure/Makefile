.PHONY: all
all: build

.PHONY: build
build:
	lake build

.PHONY: format
format:
	nix fmt
	cljstyle fix src test resources

.PHONY: format-check
format-check:
	nix fmt -- --ci
	cljstyle check src test resources

.PHONY: lint
lint:
	clj-kondo --lint src test resources

.PHONY: test
test: build
	./test-diff.sh
	PATH="$(CURDIR)/.lake/build/bin:$$PATH" clojure -M:test

.PHONY: check
check: format-check lint test
