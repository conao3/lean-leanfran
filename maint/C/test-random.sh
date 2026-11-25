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
echo "random: model tests passed, an off-by-one implementation and a signed overflow failed"
