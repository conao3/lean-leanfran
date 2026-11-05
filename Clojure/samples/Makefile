SAMPLES := todo-cli word-count roman-numerals verified-clojure sorted-search inventory generic-search typed-schemas

.PHONY: test
test:
	for s in $(SAMPLES); do $(MAKE) -C $$s test || exit 1; done
