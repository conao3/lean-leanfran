#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

export LEAN_BACKTRACE=0
module=LeanPhpTest.ControlDepth
out=test-out/depth
mkdir -p "$out"
lake build leanfran-php oracle-control-depth
.lake/build/bin/leanfran-php module generate --module-name "$module" --roots "$module.run" \
    --main "$module.run" --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file "$out/Depth.php"
php -l "$out/Depth.php"
grep -Eq 'return new L\\TailCall\(self::tc_l_LeanPhpTest_ControlDepth_chainMiddle\(' "$out/Depth.php"
grep -Eq 'return new L\\TailCall\(self::tc_l_LeanPhpTest_ControlDepth_chainEnd\(' "$out/Depth.php"
grep -Fq 'return new L\TailApply(' "$out/Depth.php"

for mode in self mutual chain cps; do
    .lake/build/bin/oracle-control-depth "$mode" 101 > "$out/c-$mode.out"
    php -d memory_limit=128M -d auto_prepend_file=vendor/autoload.php "$out/Depth.php" "$mode" 101 \
        > "$out/php-$mode.out"
    diff -u "$out/c-$mode.out" "$out/php-$mode.out"
    case "$mode" in
        self|cps) want=1000000 ;;
        mutual) want=2500000 ;;
        chain) want=3000000 ;;
    esac
    php -d memory_limit=128M -d auto_prepend_file=vendor/autoload.php "$out/Depth.php" "$mode" 1000000 \
        > "$out/deep-$mode.out"
    printf '%s\n' "$want" | diff -u - "$out/deep-$mode.out"
    printf 'depth %s: C/PHP n=101 => %s, PHP n=1000000 => %s (128M)\n' \
        "$mode" "$(cat "$out/php-$mode.out")" "$want"
done
