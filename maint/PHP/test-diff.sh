#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

export LEAN_BACKTRACE=0
lake --dir ../.. build leanfran
lake build oracle LeanPhpTest.Unsupported
mkdir -p test-out
printf 'control input\n' > test-out/diff.in

compiler=../../.lake/build/bin/leanfran
"$compiler" --lang php module generate --module-name LeanPhpTest.Vectors \
    --roots LeanPhpTest.Vectors.run LeanPhpTest.ControlIr.impossible --main LeanPhpTest.Vectors.run \
    --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file test-out/Vectors.php
php -l test-out/Vectors.php

run_php() {
    php -d memory_limit=128M -d display_errors=stderr -d auto_prepend_file=vendor/autoload.php "$@"
}

compare() {
    local mode=$1 expected=$2 entry=$3
    local native_status=0 php_status=0
    local prefix="test-out/diff-$mode"
    .lake/build/bin/oracle "$mode" < test-out/diff.in > "$prefix.c.out" 2> "$prefix.c.err" || native_status=$?
    run_php "$entry" "$mode" < test-out/diff.in > "$prefix.php.out" 2> "$prefix.php.err" || php_status=$?
    local mismatch=0
    diff -u "$prefix.c.out" "$prefix.php.out" || mismatch=1
    diff -u "$prefix.c.err" "$prefix.php.err" || mismatch=1
    if [[ "$native_status" != "$expected" || "$php_status" != "$native_status" ]]; then
        echo "diff-test $mode: expected status $expected, got C=$native_status PHP=$php_status" >&2
        mismatch=1
    fi
    if (( mismatch )); then
        return 1
    fi
    printf 'diff-test %s: stdout (%s lines), stderr (%s lines), exit %s match\n' \
        "$mode" "$(wc -l < "$prefix.c.out")" "$(wc -l < "$prefix.c.err")" "$php_status"
}

compare probe 0 test-out/Vectors.php
compare fail 1 test-out/Vectors.php
compare status 23 test-out/Vectors.php
compare twice 0 tests/Differential/Control.php

for mode in invalid-tag unreachable; do
    status=0
    run_php tests/Differential/Control.php "$mode" > "test-out/$mode.out" 2> "test-out/$mode.err" || status=$?
    test "$status" = 1
    test ! -s "test-out/$mode.out"
    printf 'INTERNAL PANIC: unreachable code has been reached\n' | diff -u - "test-out/$mode.err"
    echo "diff-test $mode: internal panic and exit 1"
done

status=0
"$compiler" --lang php module generate --module-name LeanPhpTest.Unsupported \
    --roots LeanPhpTest.Unsupported.run --search-path .lake/build/lib/lean \
    --internal-only --output text > test-out/unsupported.out 2> test-out/unsupported.err || status=$?
if [[ "$status" != 254 || -s test-out/unsupported.out ]]; then
    cat test-out/unsupported.err >&2
    echo "Expected status 254 and no PHP for missing externs, got $status" >&2
    exit 1
fi
cat test-out/unsupported.err
grep -q 'externs not in the runtime: lean_php_missing_alpha, lean_php_missing_beta' test-out/unsupported.err
