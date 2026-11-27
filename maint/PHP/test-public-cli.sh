#!/usr/bin/env bash
set -euo pipefail

cli=../../.lake/build/bin/leanfran
dir=test-out/public/stale
mkdir -p "$dir"
printf '<?php\n' > "$dir/UserFile.php"
gen() {
    "$cli" --lang php module generate --search-path .lake/build/lib/lean --module-name LeanPhpTest.Public \
        --php-namespace 'App\Lean\Stale' --output-dir "$dir" "$@"
}
gen --roots LeanPhpTest.Public.total > "$dir/first.json"
test -f "$dir/DiscountPercent.php"
gen --roots LeanPhpTest.Public.rangeWidth --output text > "$dir/second.txt"
test ! -e "$dir/DiscountPercent.php"
test -f "$dir/Range.php"
test -f "$dir/UserFile.php"
cmp "$dir/UserFile.php" <(printf '<?php\n')

set +e
gen --facade UserFile --roots LeanPhpTest.Public.total > "$dir/collision.json" 2> "$dir/collision.log"
status=$?
set -e
test "$status" -eq 255
grep -F 'refusing to overwrite a non-generated file' "$dir/collision.log"
test -f "$dir/Range.php"
cmp "$dir/UserFile.php" <(printf '<?php\n')

set +e
"$cli" --lang php module generate --search-path .lake/build/lib/lean --module-name LeanPhpTest.PublicNames \
    --php-namespace 'App\Lean\Clashing' --facade Name_2 --output-dir "$dir" \
    > "$dir/name-collision.json" 2> "$dir/name-collision.log"
status=$?
set -e
test "$status" -eq 254
grep -Fi 'PHP name collision: name_2' "$dir/name-collision.log"
test -f "$dir/Range.php"
