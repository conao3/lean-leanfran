#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/random.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp -R "$backend/tests/verify/random" "$scratch/random"
app="$scratch/random"
source="$app/src/random.c"
kinds="$app/src/kinds.c"
mk="$app/leanfran/leanfran.mk"
export NIX_HARDENING_ENABLE=""

compilers=(clang)
if [[ $(uname -s) == Linux ]]; then
    compilers+=(gcc)
fi

model_test() {
    local expected=$1 cc=$2 status=0
    shift 2
    env "$@" make -s -f "$mk" CC="$cc" leanfran-model-test >"$scratch/out" 2>"$scratch/err" || status=$?
    if [[ $status -ne $expected ]]; then
        cat "$scratch/out" "$scratch/err" >&2
        echo "expected leanfran-model-test to exit $expected with $cc, got $status" >&2
        exit 1
    fi
}

check() {
    local expected=$1 status=0
    "$compiler" check --dir "$app" >"$scratch/check" 2>"$scratch/check.err" || status=$?
    if [[ $status -ne $expected ]]; then
        cat "$scratch/check" "$scratch/check.err" >&2
        echo "expected check to exit $expected, got $status" >&2
        exit 1
    fi
}

check 0
grep -Fxq 'random.add [refines]: proved' "$scratch/check"
for cc in "${compilers[@]}"; do
    model_test 0 "$cc"
    for fn in clamp at_most add sum midpoint; do
        grep -Eq "^random\\.$fn: [0-9]+ inputs passed \\(seed 1\\)$" "$scratch/out"
    done
    grep -Fxq 'random.add: 40 inputs passed (seed 1)' "$scratch/out"
    grep -Fxq 'random.hidden: skipped: static functions are not visible to the model test' "$scratch/out"
    for fn in level_of weight wide bigger; do
        grep -Fxq "kinds.$fn: 200 inputs passed (seed 1)" "$scratch/out"
    done
    grep -Fxq "kinds.proven_value: skipped: every constructor of «Proven» of 'p' has proof fields" "$scratch/out"
done

model_test 0 clang LEANFRAN_RUNS=6 LEANFRAN_SEED=7
grep -Fxq 'random.at_most: 6 inputs passed (seed 7)' "$scratch/out"

cat >"$app/Makefile" <<'MAKE'
include leanfran/leanfran.mk

default:
	@echo default goal
MAKE
test "$(make -s -C "$app")" = "default goal"

cp "$source" "$scratch/random.c"
cat >>"$source" <<'C'

LF_MODEL("refines=addSpec")
lf_status checked(int32_t a, int32_t b, int32_t *out) {
    *out = a + b;
    return LF_OK;
}
C
"$compiler" sync --dir "$app" >/dev/null
model_test 0 clang
grep -Fxq 'random.checked: skipped: lf_status results are not generated' "$scratch/out"

sed 's/return x <= 10;/return x < 10;/' "$scratch/random.c" >"$source"
check 0
for cc in "${compilers[@]}"; do
    model_test 2 "$cc"
    grep -Fxq 'random.at_most [refines]: mismatch (seed 1, run 105)' "$scratch/err"
    grep -Fxq '  input: x=10' "$scratch/err"
    grep -Fxq '  expected: true, got: false' "$scratch/err"
    grep -Fxq 'random.clamp: 104 inputs passed (seed 1)' "$scratch/out"
    if grep -q 'runtime error' "$scratch/err"; then
        echo "an off-by-one implementation must not stop in UBSan" >&2
        exit 1
    fi
done

cp "$scratch/random.c" "$source"
cp "$kinds" "$scratch/kinds.c"
kinds_mismatch() {
    local edit=$1 fn=$2 run=$3 input=$4 results=$5
    sed "$edit" "$scratch/kinds.c" >"$kinds"
    if cmp -s "$kinds" "$scratch/kinds.c"; then
        echo "the edit '$edit' did not change kinds.c" >&2
        exit 1
    fi
    "$compiler" sync --dir "$app" >/dev/null
    for cc in "${compilers[@]}"; do
        model_test 2 "$cc"
        grep -Fxq "kinds.$fn [refines]: mismatch (seed 1, run $run)" "$scratch/err"
        grep -Fxq "  input: $input" "$scratch/err"
        grep -Fxq "  $results" "$scratch/err"
        if grep -q 'runtime error' "$scratch/err"; then
            echo "an off-by-one implementation must not stop in UBSan" >&2
            exit 1
        fi
    done
}
kinds_mismatch 's/if (x < 10)/if (x <= 10)/' level_of 172 'x=10' \
    'expected: kinds_level_mid, got: kinds_level_low'
kinds_mismatch 's/    case kinds_level_mid:/    case kinds_level_high:/' weight 1 'l=kinds_level_mid' \
    'expected: 5, got: 9'
kinds_mismatch 's/s.as.rect.w > s.as.rect.h/s.as.rect.w >= s.as.rect.h/' wide 9 \
    's=kinds_shape_rect{w=0, h=0, level=kinds_level_low}' 'expected: false, got: true'
kinds_mismatch 's/shape_size(b) > shape_size(a)/shape_size(b) >= shape_size(a)/' bigger 9 \
    'a=kinds_shape_rect{w=0, h=0, level=kinds_level_low}, b=kinds_shape_circle{r=0}' \
    'expected: kinds_shape_rect{w=0, h=0, level=kinds_level_low}, got: kinds_shape_circle{r=0}'
kinds_mismatch 's/        return b;/        return a;/' bigger 2 \
    'a=kinds_shape_circle{r=-1}, b=kinds_shape_circle{r=0}' \
    'expected: kinds_shape_circle{r=0}, got: kinds_shape_circle{r=-1}'
cp "$scratch/kinds.c" "$kinds"

sed 's/"refines=addSpec", "requires=small"/"refines=addSpec"/' "$scratch/random.c" >"$source"
check 1
grep -Fxq 'random.add [refines]: failed' "$scratch/check"
for cc in "${compilers[@]}"; do
    model_test 2 "$cc"
    grep -Eq 'random\.c:[0-9]+:[0-9]+: runtime error: signed integer overflow' "$scratch/err"
    if grep -q 'mismatch' "$scratch/err"; then
        echo "a signed overflow must stop in UBSan before the comparison" >&2
        exit 1
    fi
done
echo "random: model tests passed, off-by-one implementations and a signed overflow failed"
