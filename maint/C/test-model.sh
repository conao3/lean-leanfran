#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/../../.lake/build/bin/leanfran"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/model.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

cd "$backend"
source_file="$backend/tests/verify/model.c"
"$compiler" --lang c generate --module-name ModelOps --out-dir "$scratch"
"$compiler" --lang c build --out-dir "$scratch"
leanc -I"$scratch" -DLEAN_MODEL "$source_file" "$scratch/libmodel_ops.a" -o "$scratch/model"
"$scratch/model" >"$scratch/model.out"

while read -r kind op a b exception diagnostic; do
    status=0
    "$scratch/model" "$kind" "$op" "$a" "$b" >"$scratch/model.log" 2>&1 || status=$?
    if [[ $status != 1 ]] || ! grep -Fxq "$exception" "$scratch/model.log"; then
        echo "Lean model: expected $exception for $kind $op $a $b" >&2
        cat "$scratch/model.log" >&2
        exit 1
    fi
done < "$backend/tests/verify/undefined.txt"

export NIX_HARDENING_ENABLE=""

compilers=(clang)
if [[ $(uname -s) == Linux ]]; then
    compilers+=(gcc)
fi
for cc in "${compilers[@]}"; do
    for opt in -O0 -O2; do
        flags=(-std=c11 -Wall -Wextra -Werror -pedantic "$opt")
        "$cc" "${flags[@]}" "$source_file" -o "$scratch/native"
        "$scratch/native" >"$scratch/native.out"
        diff -u "$scratch/model.out" "$scratch/native.out"

        "$cc" "${flags[@]}" -fsanitize=undefined,float-cast-overflow \
            -fno-sanitize-recover=all "$source_file" -o "$scratch/sanitized"
        "$scratch/sanitized" >"$scratch/sanitized.out"
        diff -u "$scratch/model.out" "$scratch/sanitized.out"
        while read -r kind op a b exception diagnostic; do
            status=0
            "$scratch/sanitized" "$kind" "$op" "$a" "$b" \
                >"$scratch/sanitized.log" 2>&1 || status=$?
            if [[ $status == 0 ]] || ! grep -Eq "runtime error: .*$diagnostic" "$scratch/sanitized.log"; then
                echo "$cc $opt UBSan: expected $exception for $kind $op $a $b" >&2
                cat "$scratch/sanitized.log" >&2
                exit 1
            fi
        done < "$backend/tests/verify/undefined.txt"
        echo "$cc $opt: $(wc -l < "$scratch/model.out") values and $(wc -l < "$backend/tests/verify/undefined.txt") UBSan cases matched LeanCLib.C"
    done
done
