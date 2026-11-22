CHECK_TARGETS += test-verify

.PHONY: test-verify
test-verify: vendor/autoload.php build
	$(show-php-version)
	time bash ../../maint/PHP/test-verify.sh
