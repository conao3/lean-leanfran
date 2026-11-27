#!/usr/bin/env bash
set -euo pipefail

project_template=tests/fixtures/embed
out=$(realpath -m test-out/embed)
project="$out/project"
compiler=$(realpath ../../.lake/build/bin/leanfran)
php=$(command -v php)
temp_path="$out/php-only"

rm -rf -- "$out"
mkdir -p -- "$project" "$out/saved" "$temp_path"
cp -R -- "$project_template/." "$project/"
ln -s -- "$php" "$temp_path/php"

cd "$project"
export COMPOSER_DISABLE_NETWORK=1
composer install --no-interaction

assert_status() {
    local expected=$1 name=$2 actual=0
    shift 2
    "$@" > "$out/$name.log" 2>&1 || actual=$?
    cat "$out/$name.log"
    printf '%s exit=%s\n' "$name" "$actual"
    test "$actual" -eq "$expected"
}

php_status() {
    PATH="$temp_path" vendor/bin/leanfran status "$@"
}

compare_generated() {
    local block
    for block in Pricing Basket Catalog Receipt; do
        diff -r "$out/saved/$block" "src/$block"
    done
}

assert_status 0 sync-first env LEANFRAN_CLI=not-the-compiler \
    vendor/bin/leanfran sync --package "$project" --leanfran "$compiler"
cp -R src/{Basket,Pricing,Catalog,Receipt} "$out/saved/"
assert_status 0 sync-second env LEANFRAN_CLI="$compiler" composer lean:sync
compare_generated
composer_path="$project/vendor/bin:$project/vendor/conao3/leanfran/bin"
assert_status 0 sync-path env LEANFRAN_CLI= PATH="$composer_path:$(dirname "$compiler"):$PATH" leanfran sync
compare_generated
assert_status 1 missing-compiler env LEANFRAN_CLI= PATH="$composer_path:$temp_path" leanfran sync
grep -Fxq 'the executable `leanfran` is not on PATH (set LEANFRAN_CLI)' "$out/missing-compiler.log"
printf 'Repeated sync: PHP and manifests are byte-identical\n'

assert_status 0 pricing php -r 'require "vendor/autoload.php"; echo App\Pricing::width(new App\Pricing\Range(lo: 2, hi: 5)), "\n";'
grep -Fxq '3' "$out/pricing.log"

php run.php > "$out/php"
{
    cat .leanfran/workspace/LeanPhpEmbed.lean
    printf '\n'
    for name in Pricing Basket Catalog Receipt; do
        php -r 'echo "open LeanPhpEmbed.B", bin2hex("App\\" . $argv[1]), "\n";' "$name"
    done
    cat <<'LEAN'
open LeanPhpModels.App LeanPhpModels.App.Input

def main : IO Unit := do
  let r : Range := ⟨2, 5, by decide⟩
  IO.println (width r)
  IO.println (twiceWidth r)
  IO.println (sameRange r).lo
  IO.println (receiptWidth r)
  let order := receiptOrder {
    percent := 100, percent_le := by decide
    count := 2, count_ge := by decide
    remaining := 0, debt := -7, debt_le := by decide
    delta := -2, delta_le := by decide
    label := "♥", label_min_length := by decide
    colors := [.Blue]
    items := [1, 2], items_min_items := by decide, items_items_ge := by decide
    pair := (-10, .Special), pair_first_ge := by decide, pair_first_le := by decide
    note := none, note_min_length := by decide
    detail := some ⟨true, 2.5, [.Red]⟩
    units := 2, units_ge := by decide
    «class» := 4
  }
  IO.println order.percent
  IO.println order.count
  IO.println order.remaining
  IO.println order.debt
  IO.println order.delta
  IO.println order.label
  IO.println (match order.colors.head? with | some .Blue => "Blue" | _ => "other")
  IO.println (String.intercalate "," (order.items.map toString))
  IO.println order.pair.1
  IO.println (match order.pair.2 with | .Special => "Special" | _ => "other")
  IO.println (order.note.getD "(none)")
  IO.println ((order.detail.map (·.active)).getD false)
  IO.println ((order.detail.map (·.weight)).getD 0.0)
  IO.println (match order.detail.bind (·.colors.head?) with | some .Red => "Red" | _ => "other")
  IO.println order.units
  IO.println order.«class»
LEAN
} > .leanfran/workspace/Oracle.lean
cat >> .leanfran/workspace/lakefile.toml <<'TOML'

[[lean_exe]]
name = "oracle-embed"
root = "Oracle"
TOML
(
    cd .leanfran/workspace
    lake build oracle-embed > "$out/oracle-build" 2>&1 || { cat "$out/oracle-build"; exit 1; }
    .lake/build/bin/oracle-embed
) > "$out/oracle"
diff -u "$out/oracle" "$out/php"
printf 'C oracle and PHP (ranges and imported model round trip)\n'
cat "$out/php"
assert_status 0 model-constraints php validate.php
grep -Fq 'o.percent: percent ≤ 100' "$out/model-constraints.log"

assert_status 0 fresh php_status --package "$project"
grep -Fxq 'leanfran: all blocks up to date' "$out/fresh.log"
runtime_toolchain=$(php -r 'require "vendor/autoload.php"; echo Conao3\Leanfran\Embed\Project::TOOLCHAIN;')
test "$runtime_toolchain" = "$(cat "$OLDPWD/../../lean-toolchain")"

cp composer.json "$out/fixture-composer.json"
php -r '$file = "composer.json"; $config = json_decode(file_get_contents($file)); $config->extra->leanfran->paths = []; file_put_contents($file, json_encode($config));'
assert_status 1 explicit-scan-paths php_status
test "$(grep -c ': removed' "$out/explicit-scan-paths.log")" -eq 4
cp "$out/fixture-composer.json" composer.json

sed -i 's/width r ≤ r.hi/width r ≤ r.lo/' src/Pricing.php
assert_status 1 bad-proof env LEANFRAN_CLI="$compiler" vendor/bin/leanfran sync
grep -E '^src/Pricing\.php:18:21: error: \(lean block App\\Pricing, Lean 9:16\).*omega could not prove' "$out/bad-proof.log"
compare_generated
assert_status 0 pricing-after-failed-proof php -r 'require "vendor/autoload.php"; echo App\Pricing::width(new App\Pricing\Range(lo: 2, hi: 5)), "\n";'
diff -u "$out/pricing.log" "$out/pricing-after-failed-proof.log"
cp "$OLDPWD/$project_template/src/Pricing.php" src/Pricing.php

sed -i 's/offset (width r + width r)/)/' src/Basket.php
assert_status 1 bad-syntax env LEANFRAN_CLI="$compiler" vendor/bin/leanfran sync
grep -E '^src/Basket\.php:10:40: error: \(lean block App\\Basket, Lean 1:35\).*unexpected token' "$out/bad-syntax.log"
compare_generated
php run.php > "$out/after-syntax"
diff -u "$out/php" "$out/after-syntax"
cp "$OLDPWD/$project_template/src/Basket.php" src/Basket.php

sed -i 's/twiceWidth/twiceWidtH/' src/Receipt.php
assert_status 1 source-change php_status
grep -Fxq 'App\Receipt: stale' "$out/source-change.log"
test "$(wc -l < "$out/source-change.log")" -eq 1
cp "$OLDPWD/$project_template/src/Receipt.php" src/Receipt.php

sed -i "s/'Support'/'Init', 'Support'/" src/Basket.php
assert_status 1 import-change php_status
grep -Fxq 'App\Basket: stale' "$out/import-change.log"
grep -Fxq 'App\Receipt: stale' "$out/import-change.log"
test "$(wc -l < "$out/import-change.log")" -eq 2
cp "$OLDPWD/$project_template/src/Basket.php" src/Basket.php

sed -i 's/r.hi - r.lo/r.hi + r.lo/' src/Pricing.php
assert_status 1 dependency-change php_status
for block in Basket Pricing Receipt; do
    grep -Fxq "App\\$block: stale" "$out/dependency-change.log"
done
test "$(wc -l < "$out/dependency-change.log")" -eq 3
cp "$OLDPWD/$project_template/src/Pricing.php" src/Pricing.php

sed -i 's/int<0, 100>/int<0, 99>/' src/OrderInput.php
assert_status 1 model-change php_status
grep -Fxq 'App\Catalog: stale' "$out/model-change.log"
grep -Fxq 'App\Receipt: stale' "$out/model-change.log"
test "$(wc -l < "$out/model-change.log")" -eq 2
cp "$OLDPWD/$project_template/src/OrderInput.php" src/OrderInput.php

sed -i 's/list<Shade>/array<string, Shade>/' src/OrderInput.php
assert_status 1 unsupported-model-type env LEANFRAN_CLI="$compiler" vendor/bin/leanfran sync
grep -Fq 'App\OrderInput.colors: unsupported PHPDoc type array<string, Shade>' "$out/unsupported-model-type.log"
compare_generated
cp "$OLDPWD/$project_template/src/OrderInput.php" src/OrderInput.php

sed -i '/^{$/a\    private int $secret;' src/Input/DetailFields.php
assert_status 1 unsupported-model-shape php_status
grep -Fq 'App\Input\Detail.secret: expected a promoted public readonly property' "$out/unsupported-model-shape.log"
cp "$OLDPWD/$project_template/src/Input/DetailFields.php" src/Input/DetailFields.php

sed -i 's/OrderInput::class/UnknownModel::class/' src/Catalog.php
assert_status 1 unknown-model php_status
grep -E '^src/Catalog\.php:[0-9]+:[0-9]+: unknown Lean model class App\\UnknownModel' "$out/unknown-model.log"
cp "$OLDPWD/$project_template/src/Catalog.php" src/Catalog.php

sed -E "s/GENERATOR_VERSION = '[^']+'/GENERATOR_VERSION = 'incompatible'/" \
    vendor/conao3/leanfran/src/Lean.php > "$out/incompatible.php"
assert_status 1 generator-change env PATH="$temp_path" \
    "$php" -d auto_prepend_file="$out/incompatible.php" vendor/bin/leanfran status
test "$(grep -c ': stale$' "$out/generator-change.log")" -eq 4
assert_status 1 generator-mismatch env LEANFRAN_CLI="$compiler" \
    "$php" -d auto_prepend_file="$out/incompatible.php" vendor/bin/leanfran sync
grep -Fq 'this package expects incompatible' "$out/generator-mismatch.log"

printf 'leanprover/lean4:v0.0.0\n' > lean-toolchain
assert_status 1 toolchain-change php_status
test "$(grep -c ': stale$' "$out/toolchain-change.log")" -eq 4
assert_status 1 toolchain-mismatch env LEANFRAN_CLI="$compiler" vendor/bin/leanfran sync
grep -Fq 'lean must match lean-toolchain (0.0.0)' "$out/toolchain-mismatch.log"
rm lean-toolchain

rm src/Pricing/Range.php
assert_status 1 missing-file php_status
grep -Fxq 'App\Pricing: missing generated file (src/Pricing/Range.php)' "$out/missing-file.log"
cp "$out/saved/Pricing/Range.php" src/Pricing/Range.php

mv src/Receipt.php "$out/Receipt.php"
assert_status 1 removed-block php_status
grep -Fxq 'App\Receipt: removed (src/Receipt)' "$out/removed-block.log"
rm src/Receipt/leanfran.json
assert_status 1 removed-without-manifest php_status
grep -Fxq 'App\Receipt: removed (src/Receipt)' "$out/removed-without-manifest.log"
cp "$out/saved/Receipt/leanfran.json" src/Receipt/leanfran.json
printf 'owned by the project\n' > src/Receipt/keep.txt
assert_status 1 unmanaged-output env LEANFRAN_CLI="$compiler" vendor/bin/leanfran sync
grep -Fq 'non-generated entry in output directory' "$out/unmanaged-output.log"
test -f src/Receipt/keep.txt
rm src/Receipt/keep.txt
compare_generated
assert_status 0 check env LEANFRAN_CLI="$compiler" vendor/bin/leanfran check
test ! -e src/Receipt
assert_status 0 after-cleanup php_status

sed -i 's/Pricing::class/Unknown::class/' src/Basket.php
assert_status 1 unknown-use php_status
grep -Fq 'Lean block App\Basket uses unknown block App\Unknown' "$out/unknown-use.log"

cp "$OLDPWD/$project_template/src/Basket.php" src/Basket.php
mv "$out/Receipt.php" src/Receipt.php
cp -R "$out/saved/Receipt" src/
compare_generated
