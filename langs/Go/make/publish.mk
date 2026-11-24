CHECK_TARGETS += test-publish

.PHONY: test-publish
test-publish:
	bash ../../maint/Go/test-publish.sh
