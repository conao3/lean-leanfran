#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/samples.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/samples/." "$scratch"

guide="$backend/../../docs/c-guide.md"
guide_block() {
    awk -v start="$1" '
        /^```/ { if (inside) { if (found) exit; inside = 0 } else { inside = 1; first = 1 } next }
        inside && first { found = index($0, start) == 1; first = 0 }
        inside && found && index($0, "# ") != 1 { print }
    ' "$guide"
}
same_text() {
    local block
    block=$(guide_block "$1" | tr -s '[:space:]' ' ')
    test -n "$block"
    test "$block" = "$(tr -s '[:space:]' ' ' <"$2")"
}
same_text 'namespace Pricing' "$backend/samples/pricing/Pricing/Core.lean"
same_text '#include "pricing.h"' "$backend/samples/pricing/main.c"
same_text '# leanfran.toml' "$backend/samples/verified-clamp/leanfran.toml"
same_text '/* leanfran:lean clamp' "$backend/samples/verified-clamp/src/clamp.c"
same_text 'import LeanCModel.clamp' "$backend/samples/verified-clamp/lean/Proofs/Clamp.lean"

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
make --no-print-directory -s leanfran-model-test >"$scratch/model.out"
cat "$scratch/model.out"
grep -Fx 'clamp.clamp: 109 inputs passed (seed 1)' "$scratch/model.out"
expected='clamp(0, 10, -5) = 0, spec 0
clamp(0, 10, 0) = 0, spec 0
clamp(0, 10, 7) = 7, spec 7
clamp(0, 10, 10) = 10, spec 10
clamp(0, 10, 12) = 10, spec 10'
test "$(make --no-print-directory -s run)" = "$expected"
