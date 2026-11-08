SAMPLES := todo-cli word-count roman-numerals verified-rust sorted-search inventory generic-search
VERIFY_SAMPLES := verified-rust sorted-search inventory generic-search

.PHONY: test
test:
	$(MAKE) -C steps test
	for s in $(SAMPLES); do $(MAKE) -C $$s test || exit 1; done

.PHONY: verify
verify:
	$(MAKE) -C steps verify
	for s in $(VERIFY_SAMPLES); do $(MAKE) -C $$s verify || exit 1; done
