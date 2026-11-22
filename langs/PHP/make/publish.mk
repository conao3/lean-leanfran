CHECK_TARGETS += test-publish

.PHONY: test-publish
test-publish:
	$(show-php-version)
	bash ../../maint/PHP/test-publish.sh
