PUBLIC_CHECK_TARGETS := test-public test-public-json test-public-names test-public-skipped test-public-diff

CHECK_TARGETS += $(PUBLIC_CHECK_TARGETS)

.PHONY: public-fixtures $(PUBLIC_CHECK_TARGETS)

PUBLIC_GEN := .lake/build/bin/leanfran-php module generate --search-path .lake/build/lib/lean
PUBLIC_OUT := test-out/public

public-fixtures: vendor/autoload.php build
	$(show-php-version)
	lake build oracle-public LeanPhpTest.PublicNames LeanPhpTest.PublicSkipped LeanPhpTest.PublicExternal
	mkdir -p $(PUBLIC_OUT)
	$(PUBLIC_GEN) --module-name LeanPhpTest.Public --output-dir $(PUBLIC_OUT)/pricing \
		--php-namespace 'App\Lean\Pricing' --facade Pricing > $(PUBLIC_OUT)/pricing.json
	$(PUBLIC_GEN) --module-name LeanPhpTest.Json --output-dir $(PUBLIC_OUT)/json \
		--php-namespace 'App\Lean\Json' --roots LeanPhpTest.Json.big LeanPhpTest.Json.bigEcho \
		LeanPhpTest.Json.data LeanPhpTest.Json.shapes LeanPhpTest.Json.colors LeanPhpTest.Json.trees \
		> $(PUBLIC_OUT)/json.json
	$(PUBLIC_GEN) --module-name LeanPhpTest.PublicNames --output-dir $(PUBLIC_OUT)/names \
		--php-namespace 'App\Lean\Names' --namespace LeanPhpTest.PublicNames > $(PUBLIC_OUT)/names.json
	$(PUBLIC_GEN) --module-name LeanPhpTest.PublicSkipped --output-dir $(PUBLIC_OUT)/skipped \
		--php-namespace 'App\Lean\Skipped' > $(PUBLIC_OUT)/skipped.json
	$(PUBLIC_GEN) --module-name LeanPhpTest.PublicExternal --output-dir $(PUBLIC_OUT)/external \
		--php-namespace 'App\Lean\External' --type-module 'LeanPhpTest.Public=App\Lean\Pricing' \
		> $(PUBLIC_OUT)/external.json
	find $(addprefix $(PUBLIC_OUT)/,pricing json names skipped external) -name '*.php' -exec php -l {} + > $(PUBLIC_OUT)/lint
	.lake/build/bin/oracle-public json > $(PUBLIC_OUT)/oracle-json

test-public: public-fixtures
	phpunit --cache-directory test-out/phpunit --bootstrap tests/Public/bootstrap.php tests/Public/PublicTest.php
	php tests/Public/differential.php demo

test-public-json: public-fixtures
	phpunit --cache-directory test-out/phpunit --bootstrap tests/Public/bootstrap.php tests/Public/JsonTest.php

test-public-names: public-fixtures
	bash ../../maint/PHP/test-public-cli.sh
	phpunit --cache-directory test-out/phpunit --bootstrap tests/Public/bootstrap.php tests/Public/NamesTest.php

test-public-skipped: public-fixtures
	phpunit --cache-directory test-out/phpunit --bootstrap tests/Public/bootstrap.php tests/Public/SkippedTest.php

test-public-diff: public-fixtures
	.lake/build/bin/oracle-public facade > $(PUBLIC_OUT)/oracle-facade
	php tests/Public/differential.php facade > $(PUBLIC_OUT)/php-facade
	diff -u $(PUBLIC_OUT)/oracle-facade $(PUBLIC_OUT)/php-facade
