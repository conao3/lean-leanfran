#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
fixtures="$backend/tests/verify/translation"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/translate.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

project="$scratch/project"
mkdir -p "$project/LeanCLib" "$project/LeanCModel"
cp "$backend/lean/LeanCLib/C.lean" "$project/LeanCLib/C.lean"
cp "$fixtures/FixtureTypes.lean" "$fixtures/Oracle.lean" "$project/"
cat >"$project/lakefile.toml" <<'LAKE'
name = "translation"
defaultTargets = ["oracle"]

[[lean_lib]]
name = "LeanCLib"
globs = ["LeanCLib.+"]

[[lean_lib]]
name = "FixtureTypes"

[[lean_lib]]
name = "LeanCModel"
globs = ["LeanCModel.+"]

[[lean_exe]]
name = "oracle"
root = "Oracle"
LAKE

cd "$project"
lake build FixtureTypes LeanCLib
"$compiler" generate --module-name FixtureTypes --roots Geo.norm1,Geo.paint --prefix shapes \
    --out-dir "$scratch/shapes"
grep -Fq 'struct LF_LEAN("Geo.Point") shapes_geo_point' "$scratch/shapes/shapes.h"
grep -Fq 'struct LF_LEAN("Geo.Shape") shapes_geo_shape' "$scratch/shapes/shapes.h"

clang_args=(-I "$scratch/shapes" -I "$fixtures")
"$compiler" translate --block fixture --import FixtureTypes \
    --out "$project/LeanCModel/Fixture.lean" "$fixtures/fixture.c" -- "${clang_args[@]}" \
    >"$scratch/translated.txt" 2>"$scratch/translate.err"
if grep -q unextracted "$scratch/translate.err"; then
    cat "$scratch/translate.err" >&2
    exit 1
fi
expected=$(grep -cE '^(static )?[a-z_0-9]+ [a-z_0-9]+\(' "$fixtures/fixture.c")
test "$(wc -l <"$scratch/translated.txt")" -eq "$expected"
lake build oracle

export NIX_HARDENING_ENABLE=""
export ASAN_OPTIONS=redzone=256
flags=(-std=c11 -Wall -Wextra -Werror -pedantic -ffp-contract=off
    -I "$backend/support" "${clang_args[@]}")
cc "${flags[@]}" "$fixtures/driver.c" -o "$scratch/inputs"
"$scratch/inputs" --inputs >"$scratch/inputs.txt"
"$project/.lake/build/bin/oracle" <"$scratch/inputs.txt" >"$scratch/lean.txt"
test "$(wc -l <"$scratch/lean.txt")" -eq "$(wc -l <"$scratch/inputs.txt")"
grep -v ' = !' "$scratch/lean.txt" >"$scratch/lean-ok.txt"
sed 's/ = .*//' "$scratch/lean-ok.txt" >"$scratch/ok-inputs.txt"
grep ' = !' "$scratch/lean.txt" | grep -vE '= !(indexOutOfRange|inactiveMember)$' >"$scratch/undefined.txt"
for exc in signedOverflow divByZero shiftOutOfRange floatToIntOutOfRange; do
    grep -q "= !$exc\$" "$scratch/undefined.txt"
done
grep -q '= !indexOutOfRange$' "$scratch/lean.txt"
grep -q '^circle_radius .* = !inactiveMember$' "$scratch/lean.txt"
if grep -qE '= !(diverged|missingReturn)$' "$scratch/lean.txt"; then
    exit 1
fi
awk '{ n[$1 " " $NF]++ } n[$1 " " $NF] <= 20' "$scratch/undefined.txt" | sed 's/ = .*//' \
    >"$scratch/undefined-inputs.txt"
grep '= !indexOutOfRange$' "$scratch/lean.txt" | sed 's/ = .*//' |
    awk '($1 == "at" && $NF >= -16 && $NF < $3 + 16) || $1 == "sum_prefix"' \
    >"$scratch/out-of-range.txt"
grep -q '^at ' "$scratch/out-of-range.txt"
grep -q '^sum_prefix ' "$scratch/out-of-range.txt"
printf '%s\n' 'at Bi 0 0' 'at Bi 3 1 2 3 3' 'at Bi 3 1 2 3 -1' >"$scratch/edge-inputs.txt"
"$project/.lake/build/bin/oracle" <"$scratch/edge-inputs.txt" >"$scratch/edge.txt"
test "$(grep -c '= !indexOutOfRange$' "$scratch/edge.txt")" -eq 3

compilers=(clang)
if [[ $(uname -s) == Linux ]]; then
    compilers+=(gcc)
fi
for cc in "${compilers[@]}"; do
    for opt in -O0 -O2; do
        "$cc" "${flags[@]}" "$opt" "$fixtures/driver.c" -o "$scratch/native"
        "$scratch/native" <"$scratch/ok-inputs.txt" >"$scratch/native.txt"
        diff -u "$scratch/lean-ok.txt" "$scratch/native.txt"

        "$cc" "${flags[@]}" "$opt" -fsanitize=undefined,float-cast-overflow \
            -fno-sanitize-recover=all "$fixtures/driver.c" -o "$scratch/sanitized"
        "$scratch/sanitized" <"$scratch/ok-inputs.txt" >"$scratch/sanitized.txt"
        diff -u "$scratch/lean-ok.txt" "$scratch/sanitized.txt"
        while read -r line; do
            status=0
            "$scratch/sanitized" <<<"$line" >/dev/null 2>"$scratch/sanitized.log" || status=$?
            if [[ $status == 0 ]] || ! grep -q 'runtime error:' "$scratch/sanitized.log"; then
                echo "$cc $opt UBSan: expected undefined behavior for '$line'" >&2
                cat "$scratch/sanitized.log" >&2
                exit 1
            fi
        done <"$scratch/undefined-inputs.txt"
        echo "$cc $opt: $(wc -l <"$scratch/lean-ok.txt") translated results matched and $(wc -l <"$scratch/undefined-inputs.txt") UBSan cases trapped"

        "$cc" "${flags[@]}" "$opt" -g -fsanitize=address -fno-omit-frame-pointer \
            "$fixtures/driver.c" -o "$scratch/asan"
        "$scratch/asan" <"$scratch/ok-inputs.txt" >"$scratch/asan.txt"
        diff -u "$scratch/lean-ok.txt" "$scratch/asan.txt"
        while read -r line; do
            status=0
            "$scratch/asan" <<<"$line" >/dev/null 2>"$scratch/asan.log" || status=$?
            if [[ $status == 0 ]] || ! grep -q 'ERROR: AddressSanitizer' "$scratch/asan.log"; then
                echo "$cc $opt ASan: expected an out-of-range read for '$line'" >&2
                cat "$scratch/asan.log" >&2
                exit 1
            fi
        done <"$scratch/out-of-range.txt"
        while read -r line; do
            status=0
            "$scratch/asan" <<<"$line" >/dev/null 2>"$scratch/asan.log" || status=$?
            if [[ $status == 0 ]] || ! grep -q 'AddressSanitizer: heap-buffer-overflow' "$scratch/asan.log"; then
                echo "$cc $opt ASan: expected a heap-buffer-overflow for '$line'" >&2
                cat "$scratch/asan.log" >&2
                exit 1
            fi
        done <"$scratch/edge-inputs.txt"
        echo "$cc $opt: $(wc -l <"$scratch/asan.txt") results matched under ASan and $(($(wc -l <"$scratch/out-of-range.txt") + 3)) out-of-range reads within 16 elements trapped"
    done
done

cd "$fixtures"
"$compiler" translate --block unsupported --out "$scratch/Unsupported.lean" unsupported.c \
    -- "${clang_args[@]}" >"$scratch/unsupported.out" 2>"$scratch/unsupported.err"
test "$(grep -c ': unextracted ' "$scratch/unsupported.err")" -eq "$(wc -l <unsupported.txt)"
while read -r fn line reason; do
    if ! grep -Fxq "unsupported.c:$line: unextracted $fn: $reason" "$scratch/unsupported.err"; then
        echo "expected unsupported.c:$line: unextracted $fn: $reason" >&2
        cat "$scratch/unsupported.err" >&2
        exit 1
    fi
done <unsupported.txt
grep -Fxq "translated out_value" "$scratch/unsupported.out"
echo "translate: $(wc -l <unsupported.txt) unsupported constructs reported with their positions"
