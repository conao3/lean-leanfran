#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/samples.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/samples/." "$scratch"

cd "$scratch/pricing"
lake build
lake env "$compiler" generate --module-name Pricing.Core --roots Pricing.total \
    --prefix pricing --out-dir out
lake env "$compiler" build --out-dir out
flags=$(PKG_CONFIG_PATH=out pkg-config --cflags --libs pricing)
eval 'cc -std=c11 -Wall -Wextra -Werror main.c -o pricing-demo '"$flags"
test "$(./pricing-demo)" = 3600

cd "$scratch/verified-clamp"
"$compiler" check --require proved >"$scratch/check.out"
cat "$scratch/check.out"
grep -Fx 'clamp.clamp [refines]: proved' "$scratch/check.out"
"$compiler" status
make --no-print-directory -s leanfran-model-test
expected='clamp(0, 10, -5) = 0, spec 0
clamp(0, 10, 0) = 0, spec 0
clamp(0, 10, 7) = 7, spec 7
clamp(0, 10, 10) = 10, spec 10
clamp(0, 10, 12) = 10, spec 10'
test "$(make --no-print-directory -s run)" = "$expected"
