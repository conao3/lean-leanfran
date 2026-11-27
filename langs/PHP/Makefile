.DEFAULT_GOAL := check
.PHONY: build check format format-check test test-numeric test-runtime gen-externs externs-check samples

sample-sources := $(wildcard samples/embed-*/main.php samples/embed-*/src/*.php \
	samples/verified-*/main.php samples/verified-*/src/*.php)

show-php-version = @php -r 'printf("%s: PHP %s\n", $$argv[1], PHP_VERSION);' '$@'
PHP_COMPILER := ../../.lake/build/bin/leanfran --lang php
CHECK_TARGETS :=

-include make/*.mk

build:
	lake --dir ../.. build leanfran

check: format-check externs-check test test-numeric test-runtime $(CHECK_TARGETS) samples

format:
	mago format src tests samples/sum-to/main.php samples/pricing/main.php $(sample-sources) ../../maint/PHP

format-check:
	$(show-php-version)
	mago format --check src tests samples/sum-to/main.php samples/pricing/main.php $(sample-sources) ../../maint/PHP

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

test: vendor/autoload.php build
	$(show-php-version)
	bash ../../maint/PHP/test-diff.sh
	cd samples/sum-to/lean && lake build
	$(PHP_COMPILER) module generate --module-name SumTo --roots sumTo \
		--search-path samples/sum-to/lean/.lake/build/lib/lean --internal-only \
		--output-file test-out/samples/LeanSumTo.php
	diff -u samples/sum-to/src/_lean/LeanSumTo.php test-out/samples/LeanSumTo.php

test-numeric:
	$(show-php-version)
	bash ../../maint/PHP/test-numeric.sh

test-runtime: vendor/autoload.php
	$(show-php-version)
	phpunit --cache-directory test-out/phpunit --bootstrap vendor/autoload.php tests/Runtime

samples: build
	$(show-php-version)
	bash samples/run.sh samples/sum-to main.php
	cd samples/greet-cli/lean && lake build
	$(PHP_COMPILER) module generate --module-name Greeting --roots main --main main \
		--search-path samples/greet-cli/lean/.lake/build/lib/lean --internal-only \
		--output-file test-out/samples/LeanGreeting.php
	bash samples/run.sh samples/greet-cli -d auto_prepend_file=vendor/autoload.php \
		../../test-out/samples/LeanGreeting.php Ada
