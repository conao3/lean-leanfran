#!/usr/bin/env bash
set -euo pipefail

compiler="$(realpath .lake/build/bin/leanfran-php)"
app="$(realpath -m test-out/verify)"
mkdir -p "$app"
rm -f "$app/src/Negative.php" "$app/lean/Proofs/States.lean" "$app/lean/Proofs/Overflow.lean"
cp -R tests/fixtures/verify/. "$app/"
cd "$app"
composer install --no-interaction --no-progress
vendor/bin/leanfran check --leanfran-php "$compiler" --require proved

workspace="$app/.leanfran/workspace"
cp Oracle.lean Semantics.lean "$workspace/verification/"
cat >> "$workspace/lakefile.toml" <<'TOML'

[[lean_lib]]
name = "Semantics"
srcDir = "verification"

[[lean_exe]]
name = "verify-oracle"
root = "Oracle"
srcDir = "verification"
TOML
generate_semantics() {
    lake env "$compiler" module generate --internal-only --module-name Semantics --class 'Verification\Semantics' \
        --roots Php.add Php.sub Php.mul Php.neg Php.abs Php.intdiv Php.mod Php.fdiv Php.strlen Php.concat Php.minFloat Php.maxFloat \
        Semantics.intCompare Semantics.intMin Semantics.intMax Semantics.floatCompare Semantics.boolCompare Semantics.stringEqual \
        Semantics.index Semantics.count Semantics.matchOne Semantics.floatAdd Semantics.floatSub Semantics.floatMul \
        Semantics.floatNeg Semantics.floatAbs Semantics.natOption --output-file "$app/Generated.php" > "$app/generated.json"
}
(
    cd "$workspace"
    lake build verify-oracle +Semantics
    .lake/build/bin/verify-oracle > "$app/lean-native.out"
    generate_semantics

)
php native.php > php-native.out
diff -u lean-native.out php-native.out
php ../../tests/Verify/operations.php "$app/Generated.php"

(
    cd "$workspace"
    model=verification/LeanPhpLib/Php.lean
    cp "$model" "$app/original-Php.lean"
    trap 'cp "$app/original-Php.lean" "$model"' EXIT
    sed -i 's/checked (a + b)/checked (a - b)/' "$model"
    lake build +Semantics
    generate_semantics
    code=0
    php "$app/../../tests/Verify/operations.php" "$app/Generated.php" > "$app/mutation.out" 2>&1 || code=$?
    test "$code" != 0
    grep -Fq 'RuntimeException: add' "$app/mutation.out"
    cp "$app/original-Php.lean" "$model"
    lake build +Semantics
    generate_semantics
)
php ../../tests/Verify/operations.php "$app/Generated.php"
printf 'Arithmetic model mutation detected and restored.\n'

check_result() {
    local expected="$1" file="$2" code=0
    vendor/bin/leanfran check --leanfran-php "$compiler" --require proved > "$file" 2>&1 || code=$?
    if [[ "$code" != "$expected" ]]; then
        cat "$file"
        printf 'Expected check exit %s, got %s\n' "$expected" "$code" >&2
        exit 1
    fi
}

php_bin="$(command -v php)"
PATH=/nonexistent "$php_bin" vendor/bin/leanfran status > status-fresh.out
grep -Fx 'App\Calc\clamp refines: proved' status-fresh.out

sed -i '0,/if (\$x < \$lo)/s//if ($x > $lo)/' src/Calc.php
code=0
PATH=/nonexistent "$php_bin" vendor/bin/leanfran status > status-stale.out || code=$?
test "$code" = 1
grep -Fx 'App\Calc\clamp refines: stale' status-stale.out
grep -Fx 'App\Calc\clamp in_range: stale' status-stale.out
grep -Fx 'App\Calc\add refines: proved' status-stale.out
check_result 1 comparison.out
grep -Fx 'App\Calc\clamp refines: failed' comparison.out
cp "$app/../../tests/fixtures/verify/src/Calc.php" src/Calc.php

{
    sed -n '1,/theorem clamp.proof.refines/p' lean/Proofs/Calc.lean
    printf '  sorry\n\n'
    sed -n '/theorem clamp.proof.in_range/,$p' lean/Proofs/Calc.lean
} > ClampSorry.lean
cp ClampSorry.lean lean/Proofs/Calc.lean
check_result 1 sorry.out
grep -Fx 'App\Calc\clamp refines: sorry' sorry.out
grep -Fx 'App\Calc\clamp in_range: proved' sorry.out
cp "$app/../../tests/fixtures/verify/lean/Proofs/Calc.lean" lean/Proofs/Calc.lean

cp negative/Negative.php src/
cp negative/{States,Overflow}.lean lean/Proofs/
check_result 1 states.out
grep -Fx 'App\Calc\clamp refines: proved' states.out
grep -Fx 'App\Negative\withSorry refines: sorry' states.out
grep -Fx 'App\Negative\withAxiom refines: axioms' states.out
grep -Fx 'App\Negative\unsafeAdd refines: failed' states.out
grep -Fx 'App\Negative\missing refines: missing' states.out
grep -Fx 'App\Negative\mismatch refines: mismatch' states.out
while IFS=$'\t' read -r method reason; do
    row="$(grep -F "App\Negative\\${method} refines: unextracted (src/Negative.php:" states.out)"
    grep -Eq 'src/Negative\.php:[1-9][0-9]*:' <<< "$row"
    grep -Fq "$reason" <<< "$row"
done < negative/unextracted.tsv
printf 'All seven proof states, source positions and stale status checked.\n'

composer install --no-dev --no-interaction --no-progress
code=0
PATH=/nonexistent "$php_bin" vendor/bin/leanfran status > status-parser.out 2>&1 || code=$?
test "$code" = 1
grep -F 'composer require --dev nikic/php-parser:^5.9' status-parser.out
