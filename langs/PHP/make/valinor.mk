CHECK_TARGETS += test-valinor

.PHONY: test-valinor

test-valinor: public-fixtures
	$(show-php-version)
	phpunit --cache-directory test-out/phpunit --bootstrap tests/Public/bootstrap.php tests/Public/ValinorTest.php
