CHECK_TARGETS += test-verify

.PHONY: verify-fixture test-verify

verify-fixture: vendor/autoload.php build
	bash ../../maint/PHP/setup-verify.sh

test-verify: test-verify-pbt
	$(show-php-version)
	time bash ../../maint/PHP/test-verify.sh
