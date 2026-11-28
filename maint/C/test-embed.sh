#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/../../.lake/build/bin/leanfran"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/embed.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/tests/embed/." "$scratch"
app="$scratch/app"
out="$app/generated bindings"

expect_status() {
    local expected=$1 status=0
    shift
    (cd "$app" && "$compiler" --lang c "$@" --dir "$app") >"$scratch/diagnostics" 2>&1 || status=$?
    cat "$scratch/diagnostics"
    test "$status" -eq "$expected"
}

mv "$app/leanfran.toml" "$scratch/leanfran.toml.saved"
expect_status 254 status
grep -F 'leanfran.toml not found; create leanfran.toml' "$scratch/diagnostics"
mv "$scratch/leanfran.toml.saved" "$app/leanfran.toml"
expect_status 1 status
"$compiler" --lang c check --dir "$app"
expect_status 0 status
mkdir "$scratch/status-path"
if [[ $(uname -s) == Darwin ]]; then
    ln -s "$(command -v shasum)" "$scratch/status-path/shasum"
else
    ln -s "$(command -v sha256sum)" "$scratch/status-path/sha256sum"
fi
ln -s "$(command -v clang)" "$scratch/status-path/clang"
PATH="$scratch/status-path" "$compiler" --lang c status --dir "$app"
test -f "$app/.leanfran/c/workspace/LeanfranBlocks/invoice.lean"
test -f "$app/leanfran.manifest.json"
test "$(ar t "$out/libleanfran.a" | grep -c '^EmbedDependency\.c\.o\.export$')" -eq 1
test ! -e "$out/libleanfran.a.rsp"

expected='{"express":true,"orders":[{"price_cents":250,"qty":3,"sku":"A7"},{"price_cents":1000,"qty":1,"sku":"A7"}]}
Invalid order.qty_ge
Invalid order.sku_min_len
Invalid cart.orders_max_len
16 46 14'
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
grep -Fx 'catalog: stale' "$scratch/diagnostics"
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

manifest="$app/leanfran.manifest.json"
lean_version=$(lean --version | sed -E 's/^Lean \(version ([0-9.]+).*/\1/')
compiler_key="$("$compiler" --lang c --generator-version)/$lean_version"
grep -F "\"compiler\": \"$compiler_key\"" "$manifest"
sed -E 's/("compiler": ")[^"]+/\1different/' "$manifest" >"$scratch/manifest.json"
cp "$scratch/manifest.json" "$manifest"
expect_status 1 status
grep -Fx 'catalog: stale' "$scratch/diagnostics"

printf '/* leanfran:lean twin\ndef basePrice : UInt32 := 1\n*/\n' >"$app/src/twin.h"
expect_status 254 sync
grep -F "src/twin.h:1:1: error: Lean blocks 'catalog' (src/nested/catalog.h:1) and 'twin' both define 'basePrice'" \
    "$scratch/diagnostics"
rm "$app/src/twin.h"

printf '/* leanfran:lean extra\ndef extraPrice : UInt32 := 0\n*/\n' >"$app/src/extra.h"
"$compiler" --lang c check --dir "$app"
test -f "$out/extra.h"
rm "$app/src/extra.h"
expect_status 1 status
grep -Fx 'extra: removed' "$scratch/diagnostics"
"$compiler" --lang c sync --dir "$app"
test ! -e "$out/extra.h"
expect_status 0 status

models="$app/src/models.h"
cp "$models" "$scratch/models.h"
grep -F '#include "../src/models.h"' "$out/pricing.h"
grep -Fx 'typedef struct order pricing_order;' "$out/pricing.h"
if grep -E '^(typedef )?struct (order|cart) \{' "$out/pricing.h"; then exit 1; fi

sed 's/"ge=1", "le=1000"/"ge=1", "le=999"/' "$scratch/models.h" >"$models"
expect_status 1 status
grep -Fx 'pricing: stale' "$scratch/diagnostics"
cp "$models" "$scratch/models-changed.h"
cp -R "$out" "$scratch/models-previous"
sed 's/"ge=1", "le=999"/"min_len=1"/' "$scratch/models-changed.h" >"$models"
expect_status 254 sync
grep -E "^src/models\.h:7:14: error: 'min_len' requires a string or array field" "$scratch/diagnostics"
diff -r "$scratch/models-previous" "$out"
sed 's/= 250 := by decide/= 251 := by decide/' "$scratch/models.h" >"$models"
expect_status 254 sync
grep -E '^src/models\.h:35:[0-9]+: error:' "$scratch/diagnostics"
diff -r "$scratch/models-previous" "$out"
sed 's/LF_STRUCT(pricing) {/LF_STRUCT(missing) {/' "$scratch/models.h" >"$models"
expect_status 254 sync
grep -E "^src/models\.h:17:9: error: LF_STRUCT refers to unknown Lean block 'missing'" "$scratch/diagnostics"
perl -pe 's/^    bool express;/    char *note;\n    bool express;/' "$scratch/models.h" >"$models"
expect_status 254 sync
grep -E "^src/models\.h:19:11: error: unsupported LF_STRUCT field type 'char \*'" "$scratch/diagnostics"
diff -r "$scratch/models-previous" "$out"

mkdir -p "$app/src/config"
printf '#define APP_MAX_ORDERS "max_len=4"\n' >"$app/src/config/app_config.h"
perl -pe 's/^#include "leanfran.h"/#include "leanfran.h"\n#include "app_config.h"/; s/LF_FIELD\("max_len=4"\)/LF_FIELD(APP_MAX_ORDERS)/' "$scratch/models.h" >"$models"
expect_status 254 sync
grep -F "'app_config.h' file not found" "$scratch/diagnostics"
cat >"$app/compile_commands.json" <<JSON
[{"directory": "$app", "file": "src/main.c", "command": "cc -std=c11 -Isrc/config '-Igenerated bindings' -c src/main.c -o main.o"}]
JSON
"$compiler" --lang c check --dir "$app"
rm "$app/compile_commands.json"
expect_status 254 sync
cp "$app/leanfran.toml" "$scratch/leanfran.toml"
{ printf 'cflags = ["-Isrc/config"]\n'; cat "$scratch/leanfran.toml"; } >"$app/leanfran.toml"
"$compiler" --lang c check --dir "$app"
cp "$scratch/leanfran.toml" "$app/leanfran.toml"
cp "$scratch/models.h" "$models"
rm -r "$app/src/config"
"$compiler" --lang c check --dir "$app"
test "$(make --no-print-directory -s -C "$app" check)" = "$expected"

noclang="$scratch/noclang-path"
lean_cc=$(command -v clang)
mkdir "$noclang"
IFS=: read -r -a path_dirs <<<"$PATH"
for dir in "${path_dirs[@]}"; do
    [[ -d $dir ]] || continue
    for tool in "$dir"/*; do
        name=$(basename "$tool")
        [[ $name == clang ]] && continue
        [[ -x $tool && ! -e $noclang/$name ]] && ln -s "$tool" "$noclang/$name"
    done
done
LEAN_CC="$lean_cc" PATH="$noclang" expect_status 255 sync
grep -E '^src/models\.h:[0-9]+:1: error: LF_STRUCT requires clang on PATH' "$scratch/diagnostics"
mv "$models" "$scratch/models-saved.h"
LEAN_CC="$lean_cc" PATH="$noclang" "$compiler" --lang c check --dir "$app"
test ! -e "$out/pricing.h"
mv "$scratch/models-saved.h" "$models"
cp -R "$backend/samples/verified-clamp" "$scratch/clamp"
for command in status sync check; do
    status=0
    (cd "$scratch/clamp" && LEAN_CC="$lean_cc" PATH="$noclang" "$compiler" --lang c "$command") \
        >"$scratch/diagnostics" 2>&1 || status=$?
    cat "$scratch/diagnostics"
    test "$status" -eq 255
    grep -Fx 'src/clamp.c: error: LF_MODEL requires clang on PATH' "$scratch/diagnostics"
done
