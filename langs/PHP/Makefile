.DEFAULT_GOAL := check
.PHONY: build check format format-check test test-numeric test-runtime gen-externs externs-check

build:
	lake build leanfran-php

check: format-check externs-check test test-numeric test-runtime

format:
	mago format src tests ../../maint/PHP

format-check:
	mago format --check src tests ../../maint/PHP

vendor/autoload.php: composer.json composer.lock
	composer install --no-interaction

gen-externs: vendor/autoload.php
	mkdir -p test-out
	php ../../maint/PHP/gen-externs.php > test-out/RuntimeExterns.lean
	cp test-out/RuntimeExterns.lean LeanPhp/RuntimeExterns.lean

externs-check: vendor/autoload.php
	mkdir -p test-out
	php ../../maint/PHP/gen-externs.php > test-out/RuntimeExterns.check.lean
	diff -u LeanPhp/RuntimeExterns.lean test-out/RuntimeExterns.check.lean

test: vendor/autoload.php
	bash ../../maint/PHP/test-diff.sh

test-numeric:
	bash ../../maint/PHP/test-numeric.sh

test-runtime: vendor/autoload.php
	phpunit --cache-directory test-out/phpunit --bootstrap vendor/autoload.php tests
