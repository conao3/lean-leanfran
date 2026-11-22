.DEFAULT_GOAL := check
.PHONY: build check format format-check test test-numeric test-runtime test-static gen-externs externs-check

show-php-version = @php -r 'printf("%s: PHP %s\n", $$argv[1], PHP_VERSION);' '$@'

build:
	lake build leanfran-php

check: format-check externs-check test test-numeric test-runtime test-static

format:
	mago format src tests ../../maint/PHP

format-check:
	$(show-php-version)
	mago format --check src tests ../../maint/PHP

vendor/autoload.php: composer.json composer.lock
	composer install --no-interaction

gen-externs: vendor/autoload.php
	$(show-php-version)
	mkdir -p test-out
	php ../../maint/PHP/gen-externs.php > test-out/RuntimeExterns.lean
	cp test-out/RuntimeExterns.lean LeanPhp/RuntimeExterns.lean

externs-check: vendor/autoload.php
	$(show-php-version)
	mkdir -p test-out
	php ../../maint/PHP/gen-externs.php > test-out/RuntimeExterns.check.lean
	diff -u LeanPhp/RuntimeExterns.lean test-out/RuntimeExterns.check.lean

test: vendor/autoload.php
	$(show-php-version)
	bash ../../maint/PHP/test-diff.sh

test-numeric:
	$(show-php-version)
	bash ../../maint/PHP/test-numeric.sh

test-runtime: vendor/autoload.php
	$(show-php-version)
	phpunit --cache-directory test-out/phpunit --bootstrap vendor/autoload.php tests

test-static: vendor/autoload.php
	$(show-php-version)
	phpstan analyse --level=max --no-progress src
