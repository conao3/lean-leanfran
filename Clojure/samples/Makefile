SAMPLES := todo-cli word-count roman-numerals verified-clojure

.PHONY: test
test:
	for s in $(SAMPLES); do $(MAKE) -C $$s test || exit 1; done
