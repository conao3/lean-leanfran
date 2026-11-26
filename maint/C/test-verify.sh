#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/verify.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/tests/verify/states" "$scratch/states"
app="$scratch/states"
source="$app/src/states.c"

run() {
    local expected=$1 status=0
    shift
    "$compiler" "$@" --dir "$app" >"$scratch/out" 2>"$scratch/err" || status=$?
    cat "$scratch/out"
    if [[ $status -ne $expected ]]; then
        cat "$scratch/err" >&2
        echo "expected exit $expected, got $status: $*" >&2
        exit 1
    fi
}

expect_state() {
    grep -Fxq "states.$1 [$2]: $3" "$scratch/out" || {
        echo "expected states.$1 [$2]: $3" >&2
        exit 1
    }
}

run 1 check --require proved
for row in 'proved refines proved' 'proved changes proved' 'clamp refines proved' \
    'sorry_case refines sorry' 'axioms_case refines axioms' 'missing_case refines missing' \
    'mismatch_case refines mismatch' 'failed_case refines failed' 'unsupported refines unextracted'; do
    read -r fn label state <<<"$row"
    expect_state "$fn" "$label" "$state"
done
test "$(grep -c '^states\.' "$scratch/out")" -eq 9
grep -Fxq "src/states.c:39:57: unextracted unsupported: global variable 'counter'" "$scratch/err"
grep -Eq '^error: lean/Proofs/Failed\.lean:7:[0-9]+: Type mismatch' "$scratch/err"
grep -F '"status": "proved"' "$app/leanfran.lock"

run 1 check
expect_state sorry_case refines sorry

run 0 status
expect_state proved refines proved
expect_state sorry_case refines sorry

cp "$source" "$scratch/states.c"
perl -pe 's/^uint32_t proved\(uint32_t n\) \{ return n \+ 1; \}/uint32_t proved(uint32_t n) {\n    return n + 2;\n}/' \
    "$scratch/states.c" >"$source"
run 1 status
expect_state proved refines stale
expect_state proved changes stale
expect_state clamp refines proved
expect_state sorry_case refines sorry
run 1 check
expect_state proved refines failed
expect_state clamp refines failed
grep -Eq '^error: lean/Proofs/States\.lean:[0-9]+:[0-9]+:' "$scratch/err"
cp "$scratch/states.c" "$source"

run 1 check
sed 's/^uint32_t proved(uint32_t n) { return n + 1; }/uint32_t proved(uint32_t n)   {  return n + 1;  }/' \
    "$scratch/states.c" >"$source"
run 0 status
expect_state proved refines proved
cp "$scratch/states.c" "$source"

cp "$app/lean/Proofs/States.lean" "$scratch/States.lean"
printf '\n-- edited\n' >>"$app/lean/Proofs/States.lean"
run 1 status
expect_state clamp refines stale
cp "$scratch/States.lean" "$app/lean/Proofs/States.lean"

sed 's/"refines=clampSpec", "requires=ordered"/"refines=clampSpec", "requires=nothing"/' \
    "$scratch/states.c" >"$source"
run 1 check
expect_state clamp refines unextracted
grep -Fq 'src/states.c:15:9: could not elaborate the translated definition of clamp or its obligations' \
    "$scratch/err"
expect_state missing_case refines missing
sed 's/"refines=clampSpec", "requires=ordered"/"refines=clampSpec", "spec=missing"/' \
    "$scratch/states.c" >"$source"
run 1 check
grep -Fq "src/states.c:15:9: unextracted clamp: LF_MODEL refers to unknown Lean block 'missing'" \
    "$scratch/err"

perl -0pe 's/LF_MODEL\("refines=incSpec"\)\nuint32_t (sorry|axioms|missing|mismatch|failed)_case\(uint32_t n\) \{ return n \+ 1; \}\n\n//g; s/LF_MODEL\("refines=incSpec"\)\nuint32_t unsupported[^\n]*\n//' \
    "$scratch/states.c" >"$source"
perl -0pe 's/theorem sorry_case.*?(?=end LeanCModel)//s' "$scratch/States.lean" >"$app/lean/Proofs/States.lean"
rm "$app/lean/Proofs/Failed.lean"
run 0 check --require proved
test "$(grep -c ': proved$' "$scratch/out")" -eq 3
test "$(grep -c '^states\.' "$scratch/out")" -eq 3
run 0 status

rm "$source"
printf '/* leanfran:lean states\ndef unused : Nat := 0\n*/\n' >"$source"
run 1 status
run 0 check
test "$(grep -c '^states\.' "$scratch/out")" -eq 0
run 0 status

app="$scratch/header"
mkdir -p "$app/src" "$app/include"
printf 'sources = ["src/*.c", "include/*.h"]\n' >"$app/leanfran.toml"
cat >"$app/include/header.h" <<'C'
/* leanfran:lean header
def incSpec (n : UInt32) : UInt32 := n + 1
def addSpec (a b : Int32) : Int32 := a + b
def addOk (a b r : Int32) : Bool := r == a + b
def small (a b : Int32) : Bool := a < 100 && b < 100 && a > -100 && b > -100
*/
#include "leanfran.h"

LF_MODEL("refines=incSpec")
uint32_t inc(uint32_t n);

LF_MODEL("refines=incSpec")
uint32_t lost(uint32_t n);
C
cat >"$app/src/impl.c" <<'C'
#include "../include/header.h"

uint32_t inc(uint32_t n) { return n + 1; }

LF_MODEL("refines=addSpec", "ensures=sum:addOk", "requires=small", "spec=header")
int32_t add(int32_t a, int32_t b) { return a + b; }
C
run 1 check --require proved
for row in 'inc refines missing' 'lost refines unextracted' 'add refines missing' 'add sum missing'; do
    read -r fn label state <<<"$row"
    grep -Fxq "header.$fn [$label]: $state" "$scratch/out"
done
grep -Fxq 'include/header.h:13:10: unextracted lost: LF_MODEL function has no definition in the configured sources' \
    "$scratch/err"
model="$app/.leanfran/workspace/LeanCModel/header/File_src_simpl_dc/Fn_add.lean"
grep -Fq '= true → «add» «a» «b» = Except.ok (_root_.«addSpec» «a» «b»)' "$model"
grep -Fq '= true → ∃ r, «add» «a» «b» = Except.ok r ∧ _root_.«addOk» «a» «b» r = true' "$model"

app="$scratch/records"
cp -R "$backend/tests/verify/records" "$app"
expect_model() {
    grep -Fxq "$1: $2" "$scratch/out" || {
        echo "expected $1: $2" >&2
        exit 1
    }
}
run 0 check --require proved
expect_model 'shop.line_total [refines]' proved
expect_model 'shop.point_sum [refines]' proved
expect_model 'div.safe_div [refines]' proved
expect_model 'shop.size_weight [refines]' proved
expect_model 'shop.parcel_size [refines]' proved
for model in level_of first_or first_level level_at level_at_or first_at first_pos byte_one sign_one \
    low_level level_one tone_low; do
    expect_model "grade.$model [refines]" proved
done
for model in keep_point point_one keep_parcel parcel_one; do
    expect_model "shop.$model [refines]" proved
done
grep -Fq '∀ («xs» : Array Int32) («d» : Int32), «xs».size < 2 ^ 64 → «first_or» «xs» «d» = Except.ok' \
    "$app/.leanfran/workspace/LeanCModel/grade/File_src_sgrade_dc/Fn_first_or.lean"
run 0 status

db="$app/compile_commands.json"
cp "$db" "$scratch/compile_commands.json"
cat >"$db" <<'JSON'
[
  {"directory": ".", "file": "src/shop.c", "arguments": ["cc", "-c", "src/shop.c"]},
  {"directory": ".", "file": "src/shop.c", "arguments": ["cc", "-DSHOP_FIRST", "-c", "src/shop.c"]}
]
JSON
run 1 status
expect_model 'shop.point_sum [refines]' stale
expect_model 'div.safe_div [refines]' proved
run 1 check
expect_model 'shop.point_sum [refines]' failed
expect_model 'div.safe_div [refines]' proved
cp "$scratch/compile_commands.json" "$db"
run 0 check --require proved

cp "$app/src/shop.c" "$scratch/shop.c"
cp "$app/leanfran.lock" "$scratch/records.lock"
cp "$app/leanfran/shop.h" "$scratch/shop.h"
printf 'int broken(void) { return }\n' >>"$app/src/shop.c"
run 1 status
for model in 'shop.line_total' 'shop.point_sum' 'shop.size_weight' 'shop.parcel_size' 'div.safe_div' \
    'grade.level_of' 'grade.first_or' 'grade.first_level' 'grade.level_at' 'grade.level_at_or' 'grade.first_at' \
    'grade.first_pos' 'grade.byte_one' 'grade.sign_one' 'grade.low_level' 'grade.level_one' 'grade.tone_low' \
    'shop.keep_point' 'shop.point_one' 'shop.keep_parcel' 'shop.parcel_one'; do
    expect_model "$model [refines]" stale
done
grep -Fq "/src/shop.c: clang exited with 1" "$scratch/err"
grep -Eq '/src/shop\.c:[0-9]+:[0-9]+: error: expected expression' "$scratch/err"
run 254 check
grep -Fq "/src/shop.c: clang exited with 1" "$scratch/err"
cmp "$scratch/records.lock" "$app/leanfran.lock"
cmp "$scratch/shop.h" "$app/leanfran/shop.h"
cp "$scratch/shop.c" "$app/src/shop.c"
run 0 status

app="$scratch/files"
cp -R "$backend/tests/verify/files" "$app"
run 0 check --require proved
for model in fa fb File_src_sa_dc.twin File_src_sb_dc.twin; do
    expect_model "dup.$model [refines]" proved
done
test "$(grep -c '^dup\.' "$scratch/out")" -eq 4
workspace="$app/.leanfran/workspace/LeanCModel/dup"
grep -Fq '(«x» + (1 : UInt32))' "$workspace/File_src_sa_dc/Fn_helper.lean"
grep -Fq '(«x» + (2 : UInt32))' "$workspace/File_src_sb_dc/Fn_helper.lean"
grep -Fxq 'namespace LeanCModel.«dup».File_src_sb_dc' "$workspace/File_src_sb_dc/Fn_twin.lean"
grep -Fxq 'open LeanCModel.«dup».File_src_sb_dc' "$workspace/File_src_sb_dc/Fn_fb.lean"
run 0 status
for model in fa fb File_src_sa_dc.twin File_src_sb_dc.twin; do
    expect_model "dup.$model [refines]" proved
done
perl -pi -e 's/^def bSpec \(x : UInt32\) : UInt32 := x \+ 2$/def bSpec (x : UInt32) : UInt32 := x + 1/' "$app/src/a.c"
run 1 status
expect_model 'dup.fb [refines]' stale
run 1 check --require proved
expect_model 'dup.fb [refines]' failed
grep -Fq "lean/Proofs/Dup.lean:11:2: Tactic \`rfl\` failed" "$scratch/err"

cp -R "$backend/tests/verify/trust" "$scratch/trust"
app="$scratch/trust"
run 1 check
expect_model 'ch.inc [refines]' failed
grep -Fq "error: lean/Proofs/Ch.lean:13: the kernel rejected LeanCModel.ch.inc.proof.refines or a declaration it uses: while replaying declaration 'LeanCModel.ch.unchecked'" \
    "$scratch/err"
expect_model 'inst.bump [refines]' unextracted
grep -Fq 'error: lean/Proofs/Inst.lean:5: the translated definition uses the instance instHAddUInt32_leanfranBlocks from LeanfranBlocks.inst on standard types' \
    "$scratch/err"
for model in fp.muladd fp.widen lim.below; do
    expect_model "$model [refines]" proved
done
run 0 status

cp "$app/src/lim.c" "$scratch/lim.c"
sed 's/LIMIT = 10/LIMIT = 11/' "$scratch/lim.c" >"$app/src/lim.c"
run 1 status
expect_model 'lim.below [refines]' stale
expect_model 'fp.muladd [refines]' proved
run 1 check
expect_model 'lim.below [refines]' failed
cp "$scratch/lim.c" "$app/src/lim.c"
run 1 check
run 0 status

flags_case() {
    local flags=$1
    printf '[{"directory": ".", "file": "src/fp.c", "arguments": ["cc", %s"-c", "src/fp.c"]}]\n' "$flags" \
        >"$app/compile_commands.json"
    run 1 status
}
flags_case '"-ffast-math", '
expect_model 'fp.muladd [refines]' stale
expect_model 'fp.widen [refines]' proved
run 1 check
expect_model 'fp.muladd [refines]' unextracted
grep -Fq 'src/fp.c:8:8: unextracted muladd: compiled with -ffast-math, which changes double results' "$scratch/err"
flags_case '"-ffp-contract=fast", '
run 1 check
grep -Fq 'src/fp.c:8:8: unextracted muladd: compiled with -ffp-contract=fast, which can contract double operations' \
    "$scratch/err"
if [[ $(uname -s) == Linux ]]; then
    flags_case '"-mfma", '
else
    flags_case ''
fi
run 1 check
grep -Fq 'src/fp.c:8:8: unextracted muladd: the target has FMA instructions and the flags do not contain -ffp-contract=off' \
    "$scratch/err"
if [[ $(uname -s) == Linux ]]; then
    flags_case '"-m32", "-ffreestanding", "-ffp-contract=off", '
    expect_model 'fp.widen [refines]' stale
    run 1 check
    grep -Fq 'src/fp.c:11:15: unextracted widen: the target is not LP64: long has 4 bytes, the translation needs 8' \
        "$scratch/err"
    expect_model 'fp.widen [refines]' unextracted
fi
rm "$app/compile_commands.json"
run 1 check
expect_model 'fp.muladd [refines]' proved
expect_model 'fp.widen [refines]' proved

echo "verify: obligation states, stale results, same-named functions in two files, kernel replay, instances, target and floating-point flags checked"
