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

cd "$backend/tests/types"
types="$scratch/types"
roots=Typed.mixed,Typed.checkMixed,Typed.tree,Typed.checkTree,Typed.color,Typed.single
roots+=,Typed.arrays,Typed.lists,Typed.bytes,Typed.naturals,Typed.integers,Typed.options
roots+=,Checked.echo,Checked.batch,Schema.sample
roots+=,Typed.multiple,Typed.checked,Typed.checkUnit,Typed.sampleArray,Typed.empty,Typed.positional
"$compiler" generate --module-name PublicTypes --roots "$roots" --out-dir "$types"
"$compiler" build --out-dir "$types"

rejected() {
    local diagnostic=$1
    shift
    local status=0
    "$compiler" generate --module-name PublicTypes --out-dir "$scratch/collision" "$@" \
        >"$scratch/rejected" 2>&1 || status=$?
    test "$status" -eq 254
    grep -F "$diagnostic" "$scratch/rejected"
    test ! -e "$scratch/collision"
}

rejected 'C name collision: public_types_foo_bar' --roots Collision.fooBar,Collision.foo_bar
rejected 'C name collision: public_types_collision_fields.foo_bar' --roots Collision.echo
rejected 'unsupported parameter type' --roots Typed.unsupported
rejected 'Checked.Undecidable.proof has no Decidable instance' --roots Checked.bad

renamed="$scratch/renamed"
"$compiler" generate --module-name PublicTypes --out-dir "$renamed" \
    --roots Collision.echo,Collision.fooBar,Collision.foo_bar \
    --rename Collision.fooBar=camel_case --rename Collision.Fields.fooBar=camel_case \
    --rename Collision.Fields=renamed_fields
grep -F 'lf_status public_types_camel_case(' "$renamed/public_types.h"
grep -F 'bool camel_case;' "$renamed/public_types.h"
grep -F 'typedef struct public_types_renamed_fields' "$renamed/public_types.h"
"$compiler" build --out-dir "$renamed"

types_args=(-I"$types" -UNDEBUG -Wall -Wextra -Werror "$backend/tests/types/roundtrip.c")
leanc "${types_args[@]}" "$types/libpublic_types.a" -o "$scratch/roundtrip"
"$scratch/roundtrip" </dev/null
mkdir -p "$scratch/oracle/LeanfranC"
lean -R "$types" -o "$scratch/oracle/LeanfranC/Json.olean" "$types/LeanfranC/Json.lean"
LEAN_PATH="$scratch/oracle:$PWD/.lake/build/lib/lean" lean --run JsonOracle.lean >"$scratch/lean.json"
json_args=(-I"$types" -UNDEBUG -Wall -Wextra -Werror "$backend/tests/types/json.c")
leanc "${json_args[@]}" "$types/libpublic_types.a" -o "$scratch/json"
"$scratch/json" </dev/null >"$scratch/c.json"
cmp "$scratch/lean.json" "$scratch/c.json"
if [[ $(uname -s) == Linux ]]; then
    lean_include="$(lean --print-prefix)/include"
    strict=(-std=c11 -O2 -Wall -Wextra -Werror -pedantic -isystem "$lean_include")
    for source in public_types leanfran; do
        gcc "${strict[@]}" -c "$types/$source.c" -o "$scratch/gcc_$source.o"
        clang "${strict[@]}" -Wno-unused-command-line-argument \
            -c "$types/$source.c" -o "$scratch/clang_$source.o"
    done
    leanc "${types_args[@]}" "${sanitizer[@]}" "$types/public_types.c" "$types/leanfran.c" \
        "$types/libpublic_types.a" -o "$scratch/roundtrip_sanitized"
    "$scratch/roundtrip_sanitized" </dev/null
    leanc "${json_args[@]}" "${sanitizer[@]}" "$types/public_types.c" "$types/leanfran.c" \
        "$types/libpublic_types.a" -o "$scratch/json_sanitized"
    "$scratch/json_sanitized" </dev/null >"$scratch/c-sanitized.json"
    cmp "$scratch/lean.json" "$scratch/c-sanitized.json"
fi
