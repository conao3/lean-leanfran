CHECK_TARGETS += test-embed-scan test-embed

.PHONY: test-embed-scan test-embed

test-embed-scan: vendor/autoload.php
	$(show-php-version)
	phpunit --cache-directory test-out/phpunit --bootstrap vendor/autoload.php tests/Embed

test-embed: build
	$(show-php-version)
	time bash ../../maint/PHP/test-embed.sh
