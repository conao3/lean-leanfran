CHECK_TARGETS += test-embed-samples test-embed-static

.PHONY: test-embed-samples test-embed-static

samples: test-embed-samples

test-embed-samples: build
	$(show-php-version)
	time bash ../../maint/PHP/test-embed-samples.sh

test-embed-static: test-embed test-embed-samples
	$(show-php-version)
	time bash ../../maint/PHP/test-embed-static.sh
