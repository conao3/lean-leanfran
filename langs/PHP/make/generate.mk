CHECK_TARGETS += test-generate
.PHONY: test-generate

test-generate: build vendor/autoload.php
	$(show-php-version)
	bash ../../maint/test-generate.sh ../../.lake/build/bin/leanfran php
