#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/embed.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/tests/embed/." "$scratch"
app="$scratch/app"
out="$app/generated bindings"

expect_status() {
    local expected=$1 status=0
    shift
    "$compiler" "$@" --dir "$app" >"$scratch/diagnostics" 2>&1 || status=$?
    cat "$scratch/diagnostics"
    test "$status" -eq "$expected"
}

expect_status 1 status
"$compiler" check --dir "$app"
expect_status 0 status
mkdir "$scratch/status-path"
if [[ $(uname -s) == Darwin ]]; then
    ln -s "$(command -v shasum)" "$scratch/status-path/shasum"
else
    ln -s "$(command -v sha256sum)" "$scratch/status-path/sha256sum"
fi
PATH="$scratch/status-path" "$compiler" status --dir "$app"
test -f "$app/.leanfran/workspace/LeanfranBlocks/invoice.lean"
test -f "$out/leanfran.manifest.json"
test "$(ar t "$out/libleanfran.a" | grep -c '^EmbedDependency\.c\.o\.export$')" -eq 1
test ! -e "$out/libleanfran.a.rsp"

expected='16 46 14'
flags=$(PKG_CONFIG_PATH="$out" pkg-config --cflags --libs leanfran)
eval 'cc -std=c11 -Wall -Wextra -Werror "$app/src/main.c" -o "$scratch/pc-consumer" '"$flags"
test "$("$scratch/pc-consumer")" = "$expected"
test "$(make --no-print-directory -s -C "$app" check)" = "$expected"
cmake -S "$app" -B "$scratch/cmake" "-Dleanfran_DIR=$out"
cmake --build "$scratch/cmake"
test "$("$scratch/cmake/consumer")" = "$expected"

cp -R "$out" "$scratch/previous"
header="$app/src/nested/catalog.h"
cp "$header" "$scratch/catalog.h"
sed 's/basePrice = 16/basePrice = 17/' "$scratch/catalog.h" >"$header"
expect_status 1 status
grep -F 'stale: catalog' "$scratch/diagnostics"
expect_status 254 sync
grep -E '^src/nested/catalog\.h:5:50: error:' "$scratch/diagnostics"
diff -r "$scratch/previous" "$out"

sed 's/by decide/by sorry/' "$scratch/catalog.h" >"$header"
expect_status 254 sync
grep -Ei 'src/nested/catalog\.h:5:[0-9]+: error:.*sorry' "$scratch/diagnostics"
diff -r "$scratch/previous" "$out"

sed 's/theorem basePrice_checked/set_option warningAsError false in theorem basePrice_checked/; s/by decide/by sorry/'     "$scratch/catalog.h" >"$header"
expect_status 254 sync
grep -F "'basePrice_checked' uses sorryAx" "$scratch/diagnostics"
diff -r "$scratch/previous" "$out"

printf '/* leanfran:lean catalog\ndef broken : String := "before */ after"\n' >"$header"
expect_status 254 sync
grep -E '^src/nested/catalog\.h:2:[0-9]+: error:' "$scratch/diagnostics"
diff -r "$scratch/previous" "$out"
cp "$scratch/catalog.h" "$header"

printf '/* leanfran:lean catalog\n*/\n' >"$app/src/duplicate.h"
expect_status 254 sync
grep -F "duplicate Lean block 'catalog'" "$scratch/diagnostics"
diff -r "$scratch/previous" "$out"
rm "$app/src/duplicate.h"

manifest="$out/leanfran.manifest.json"
sed -E 's/("compiler": ")[a-f0-9]+/\1different/' "$scratch/previous/leanfran.manifest.json" >"$manifest"
expect_status 1 status
grep -F 'stale: leanfran-c' "$scratch/diagnostics"

printf '/* leanfran:lean extra\ndef extraPrice : UInt32 := 0\n*/\n' >"$app/src/extra.h"
"$compiler" check --dir "$app"
test -f "$out/extra.h"
rm "$app/src/extra.h"
expect_status 1 status
grep -F 'stale: extra' "$scratch/diagnostics"
"$compiler" sync --dir "$app"
test ! -e "$out/extra.h"
expect_status 0 status
