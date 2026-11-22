#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

module=LeanPhpTest.ControlComplexity
lake build leanfran-php "$module"
mkdir -p test-out
roots=()
for name in arrayPush arraySet stringPush stringAppend bytePush byteSet; do
    roots+=("$module.$name")
done
.lake/build/bin/leanfran-php module generate --module-name "$module" --roots "${roots[@]}" \
    --class 'Leanfran\Generated\Complexity' --search-path .lake/build/lib/lean \
    --internal-only --output text --output-file test-out/Complexity.php
php -d memory_limit=128M tests/Differential/Complexity.php
