CHECK_TARGETS += test-static test-static-docs

.PHONY: test-static test-static-docs

phpstan-public = phpstan analyse --no-progress --memory-limit=512M --autoload-file="$$(dirname "$$(readlink -f "$$(command -v phpunit)")")/vendor/autoload.php"

test-static: public-fixtures
	$(show-php-version)
	$(phpstan-public)

test-static-docs: public-fixtures
	$(show-php-version)
	mkdir -p test-out/static
	cp tests/Public/static-invalid.php.fixture test-out/static/invalid.php
	@status=0; $(phpstan-public) --error-format=json test-out/static/invalid.php > test-out/static/diagnostics.json || status=$$?; \
		test "$$status" -eq 1 || { cat test-out/static/diagnostics.json; exit 1; }
	php ../../maint/PHP/check-static-diagnostics.php < test-out/static/diagnostics.json
