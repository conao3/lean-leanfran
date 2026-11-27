#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

if (( $# > 2 )); then
    echo 'Usage: fuzz.sh [SEED] [N]' >&2
    exit 2
fi
seed=${1-1}
count=${2-2000}
out=test-out/fuzz
mkdir -p "$out"
input=$(mktemp -d "$out/run.XXXXXXXX")
trap 'rm -r "$input"' EXIT
php ../../maint/PHP/fuzz-gen.php "$seed" "$count" > "$input/rows.tsv"

lake --dir ../.. build leanfran
lake build oracle-fuzz
../../.lake/build/bin/leanfran --lang php module generate --module-name LeanPhpTest.Fuzz \
    --roots LeanPhpTest.Fuzz.evalRow --class 'Leanfran\Generated\Fuzz' --search-path .lake/build/lib/lean \
    --internal-only --output text --output-file "$input/Fuzz.php"

native_status=0
php_status=0
LEAN_BACKTRACE=0 .lake/build/bin/oracle-fuzz < "$input/rows.tsv" > "$input/c.out" 2> "$input/c.err" || native_status=$?
php -d memory_limit=128M -d display_errors=stderr tests/Differential/Fuzz.php "$input/Fuzz.php" \
    < "$input/rows.tsv" > "$input/php.out" 2> "$input/php.err" || php_status=$?
if (( native_status == 0 && php_status == 0 )) && cmp -s "$input/c.out" "$input/php.out"; then
    printf 'FUZZ PASS seed=%s N=%s (%s rows)\n' "$seed" "$count" "$(wc -l < "$input/rows.tsv")"
    exit 0
fi

printf 'FUZZ FAIL seed=%s N=%s (C exit=%s, PHP exit=%s)\n' "$seed" "$count" "$native_status" "$php_status" >&2
cat "$input/c.err" "$input/php.err" >&2
exec 3< "$input/c.out" 4< "$input/php.out"
line=0
while IFS= read -r row; do
    line=$((line + 1))
    c_end=0
    php_end=0
    IFS= read -r c_line <&3 || c_end=1
    IFS= read -r php_line <&4 || php_end=1
    if (( c_end || php_end )) || [[ "$c_line" != "$php_line" ]]; then
        printf 'Input row %d: %s\nC: %s\nPHP: %s\n' "$line" "$row" "$c_line" "$php_line" >&2
        exit 1
    fi
done < "$input/rows.tsv"
echo 'Outputs have extra lines or a program failed after processing the input.' >&2
exit 1
