SAMPLES := todo-cli

.PHONY: test
test:
	for s in $(SAMPLES); do $(MAKE) -C $$s test || exit 1; done
