#!/usr/bin/env bash
set -euo pipefail

cd test-out/verify
trap 'rm -f src/Properties.php' EXIT
cp pbt/Properties.php src/Properties.php
phpunit --cache-directory ../phpunit --bootstrap vendor/autoload.php pbt/PropertiesTest.php
