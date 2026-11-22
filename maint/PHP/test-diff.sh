#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

export LEAN_BACKTRACE=0
lake build leanfran-php oracle LeanPhpTest.Unsupported
mkdir -p test-out

compiler=.lake/build/bin/leanfran-php
"$compiler" module generate --module-name LeanPhpTest.Vectors \
    --roots LeanPhpTest.Vectors.run --main LeanPhpTest.Vectors.run \
    --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file test-out/Vectors.php
php -l test-out/Vectors.php
.lake/build/bin/oracle probe > test-out/oracle.txt 2> test-out/oracle.err
php -d memory_limit=128M -d auto_prepend_file=vendor/autoload.php test-out/Vectors.php probe \
    > test-out/php.txt 2> test-out/php.err
diff -u test-out/oracle.txt test-out/php.txt
diff -u test-out/oracle.err test-out/php.err
echo "diff-test: $(wc -l < test-out/oracle.txt) lines match"

native_status=0
php_status=0
.lake/build/bin/oracle fail > test-out/oracle-fail.txt 2> test-out/oracle-fail.err || native_status=$?
php -d auto_prepend_file=vendor/autoload.php test-out/Vectors.php fail \
    > test-out/php-fail.txt 2> test-out/php-fail.err || php_status=$?
if [[ "$native_status" != 1 || "$php_status" != "$native_status" ]]; then
    echo "Expected exit status 1 from both programs, got C=$native_status PHP=$php_status" >&2
    exit 1
fi
diff -u test-out/oracle-fail.txt test-out/php-fail.txt
diff -u test-out/oracle-fail.err test-out/php-fail.err
echo "diff-test: uncaught IO error and exit status $php_status match"

status=0
"$compiler" module generate --module-name LeanPhpTest.Unsupported \
    --roots LeanPhpTest.Unsupported.run --search-path .lake/build/lib/lean \
    --internal-only --output text > test-out/unsupported.out 2> test-out/unsupported.err || status=$?
if [[ "$status" != 254 || -s test-out/unsupported.out ]]; then
    cat test-out/unsupported.err >&2
    echo "Expected status 254 and no PHP for missing externs, got $status" >&2
    exit 1
fi
cat test-out/unsupported.err
grep -q 'externs not in the runtime: lean_php_missing_alpha, lean_php_missing_beta' test-out/unsupported.err
