#!/usr/bin/env bash
set -euo pipefail

compiler="$(realpath ../../.lake/build/bin/leanfran)"
app="$(realpath -m test-out/verify)"
mkdir -p "$app"
rm -f "$app/src/Negative.php" "$app/src/Properties.php" "$app/lean/Proofs/States.lean" "$app/lean/Proofs/Overflow.lean"
cp -R tests/fixtures/verify/. "$app/"
cd "$app"
composer install --no-interaction --no-progress
LEANFRAN_CLI="$compiler" vendor/bin/leanfran check --require proved
