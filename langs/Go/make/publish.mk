CHECK_TARGETS += test-publish

.PHONY: test-publish
test-publish: build
	bash ../../maint/Go/test-publish.sh
