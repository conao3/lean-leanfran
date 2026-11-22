CHECK_TARGETS += test-verify-samples

.PHONY: test-verify-samples

samples: test-verify-samples

test-verify-samples: build
	$(show-php-version)
	time bash ../../maint/PHP/test-verify-samples.sh
