CHECK_TARGETS += test-schema

.PHONY: test-schema schema-oracle schema-oracle-check

SCHEMA_ORACLE := tests/Public/schema/typescript.json

test-schema: public-fixtures
	$(show-php-version)
	php tests/Public/schema.php $(SCHEMA_ORACLE)

schema-oracle: public-fixtures
	bash ../../maint/PHP/schema-oracle.sh

schema-oracle-check: schema-oracle
	diff -u $(SCHEMA_ORACLE) test-out/schema/typescript.json
	php tests/Public/schema.php test-out/schema/typescript.json
