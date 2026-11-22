CHECK_TARGETS += test-verify-pbt

.PHONY: test-verify-pbt
test-verify-pbt: verify-fixture
	$(show-php-version)
	time bash ../../maint/PHP/test-verify-pbt.sh
