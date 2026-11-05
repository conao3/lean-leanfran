.PHONY: all
all: build

.PHONY: build
build:
	lake build

.PHONY: format
format:
	nix fmt
	cljstyle fix src test resources samples

.PHONY: format-check
format-check:
	nix fmt -- --ci
	cljstyle check src test resources samples

.PHONY: lint
lint:
	clj-kondo --lint src test resources samples/todo-cli/src samples/word-count/src samples/verified-clojure/src

.PHONY: test
test: build
	./test-diff.sh
	PATH="$(CURDIR)/.lake/build/bin:$$PATH" clojure -M:test
	$(MAKE) -C samples test

.PHONY: check
check: format-check lint test

.PHONY: jar
jar:
	clojure -T:build jar

.PHONY: deploy
deploy:
	clojure -T:build deploy
