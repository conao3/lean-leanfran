#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )); then
    echo 'usage: samples/run.sh SAMPLE_DIR PHP_ARGS...' >&2
    exit 2
fi

cd "$1"
shift
php -r 'printf("%s: PHP %s\n", basename(getcwd()), PHP_VERSION);'
composer update --no-interaction --no-progress --no-audit
output=$(mktemp)
trap 'rm -f "$output"' EXIT
php "$@" > "$output"
diff -u expected.txt "$output"
printf '%s: output matches expected.txt\n' "${PWD##*/}"
