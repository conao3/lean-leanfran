#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/check.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

cd "$backend/tests/cases"
out="$scratch/public"
"$compiler" generate --module-name Examples.PublicApi --out-dir "$out"
"$compiler" generate --module-name Examples.PublicApi --out-dir "$scratch/repeat"
diff -r "$out" "$scratch/repeat"
"$compiler" build --out-dir "$out"

status=0
"$compiler" generate --module-name Examples.PublicApi --roots Example.unsupported \
    --out-dir "$scratch/invalid" >"$scratch/rejected" 2>&1 || status=$?
test "$status" -eq 254
grep -F 'unsupported parameter type' "$scratch/rejected"
test ! -e "$scratch/invalid"
"$compiler" generate --module-name Examples.PublicApi --roots Example.lookup \
    --prefix selected --out-dir "$scratch/selected"
grep -F 'lf_status selected_lookup(' "$scratch/selected/selected.h"
if grep -F 'selected_counter(' "$scratch/selected/selected.h" ||
    grep -F 'public_api_hidden(' "$out/public_api.h"; then
    exit 1
fi

lake build oracle
oracle="$PWD/.lake/build/bin/oracle"
cc_args=(-I"$out" -UNDEBUG -Wall -Wextra)
link_public() {
    local test_name=$1
    shift
    leanc "${cc_args[@]}" "$backend/tests/$test_name.c" "$@" "$out/libpublic_api.a" \
        -o "$scratch/$test_name"
}

compare() {
    local expected=0 actual=0
    "$oracle" "$@" </dev/null >"$scratch/lean.stdout" 2>"$scratch/lean.stderr" || expected=$?
    "$scratch/consumer" "$@" </dev/null >"$scratch/c.stdout" 2>"$scratch/c.stderr" || actual=$?
    diff -u "$scratch/lean.stdout" "$scratch/c.stdout"
    diff -u "$scratch/lean.stderr" "$scratch/c.stderr"
    test "$actual" -eq "$expected"
}

link_public consumer
compare 3
compare 9 fail
link_public initialization
"$scratch/initialization" </dev/null
link_public refcount
"$scratch/refcount" </dev/null

sed '/^lf_status public_api_greeting(/,/^}/ { /    lean_dec(result);/d; }' \
    "$out/public_api.c" >"$scratch/missing_dec.c"
sed '/^lf_status public_api_retained_for_refcount(/,/^}/ {
    /    lf_status status = lf_copy_string(lean_io_result_get_value(result), out, err);/a\
    lean_dec(lean_io_result_get_value(result));
}' "$out/public_api.c" >"$scratch/extra_dec.c"
for source in missing_dec extra_dec; do
    link_public refcount "$scratch/$source.c"
    status=0
    "$scratch/refcount" </dev/null >"$scratch/refcount.log" 2>&1 || status=$?
    test "$status" -eq 1
    grep -F 'mimalloc live blocks changed' "$scratch/refcount.log"
done

"$compiler" generate --module-name Examples.Broken --roots sample --out-dir "$scratch/broken"
"$compiler" build --out-dir "$scratch/broken"
leanc -UNDEBUG -I"$scratch/broken" "$backend/tests/initialization_failure.c" \
    "$scratch/broken/libbroken.a" -o "$scratch/initialization_failure"
LEANFRAN_TEST_INIT_ERROR=1 "$scratch/initialization_failure" </dev/null

if [[ $(uname -s) == Linux ]]; then
    export ASAN_OPTIONS=detect_leaks=1:abort_on_error=1
    export LSAN_OPTIONS="suppressions=$backend/tests/lsan.supp:print_suppressions=0"
    export UBSAN_OPTIONS=halt_on_error=1
    sanitizer=(-fsanitize=address,undefined -fno-omit-frame-pointer -no-pie)
    link_public consumer "${sanitizer[@]}" "$out/public_api.c" "$out/leanfran.c"
    compare 3
    compare 9 fail
    link_public initialization "${sanitizer[@]}" "$out/public_api.c" "$out/leanfran.c"
    ASAN_OPTIONS="$ASAN_OPTIONS:use_sigaltstack=0" "$scratch/initialization" </dev/null
fi
