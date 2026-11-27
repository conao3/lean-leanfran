#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/../../.lake/build/bin/leanfran"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/check.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

release=$(sed -nE 's/^#define LEANFRAN_VERSION "([^"]*)"$/\1/p' "$backend/support/leanfran.h")
lean_version=$(lean --version | sed -E 's/^Lean \(version ([0-9.]+).*/\1/')
test "$("$compiler" --lang c --version)" = "leanfran --lang c $release (Lean $lean_version)"
"$compiler" --lang c --generator-version | grep -Eqx '[0-9]+'
"$compiler" --lang c --help | grep -Fx 'exit codes: 0 success, 1 out-of-date output or unmet obligations (status, check), 252 invalid parameters, 254 input that cannot be converted, 255 other errors'

cd "$backend/tests/cases"
out="$scratch/public"
"$compiler" --lang c generate --module-name Examples.PublicApi --out-dir "$out"
"$compiler" --lang c generate --module-name Examples.PublicApi --out-dir "$scratch/repeat"
diff -r "$out" "$scratch/repeat"
"$compiler" --lang c build --out-dir "$out"

status=0
"$compiler" --lang c generate --module-name Examples.PublicApi --roots Example.unsupported \
    --out-dir "$scratch/invalid" >"$scratch/rejected" 2>&1 || status=$?
test "$status" -eq 254
grep -F 'unsupported parameter type' "$scratch/rejected"
test ! -e "$scratch/invalid"
for root in safeHalf lastIndex; do
    status=0
    "$compiler" --lang c generate --module-name Examples.Dependent --roots "Dependent.$root" \
        --out-dir "$scratch/dependent" >"$scratch/rejected" 2>&1 || status=$?
    test "$status" -eq 254
    grep -Fx "leanfran --lang c: 'Dependent.$root' has a parameter or result type that depends on parameter 'n'" \
        "$scratch/rejected"
    if grep -E 'PANIC|backtrace' "$scratch/rejected"; then
        exit 1
    fi
    test ! -e "$scratch/dependent"
done
"$compiler" --lang c generate --module-name Examples.Dependent --out-dir "$scratch/dependent" 2>"$scratch/skipped"
grep -F 'dependent_half(' "$scratch/dependent/dependent.h"
test "$(grep -c "^leanfran --lang c: skipping 'Dependent\.[a-zA-Z]*' has a parameter or result type that depends on parameter 'n'$" \
    "$scratch/skipped")" -eq 2
if grep -E 'PANIC|backtrace' "$scratch/skipped"; then
    exit 1
fi
"$compiler" --lang c generate --module-name Examples.PublicApi --roots Example.lookup \
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

"$compiler" --lang c generate --module-name Examples.Broken --roots sample --out-dir "$scratch/broken"
"$compiler" --lang c build --out-dir "$scratch/broken"
leanc -UNDEBUG -I"$scratch/broken" "$backend/tests/initialization_failure.c" \
    "$scratch/broken/libbroken.a" -o "$scratch/initialization_failure"
LEANFRAN_TEST_INIT_ERROR=1 "$scratch/initialization_failure" </dev/null

for module in SharedFirst SharedSecond; do
    "$compiler" --lang c generate --module-name "Examples.$module" --out-dir "$scratch/$module"
    "$compiler" --lang c build --out-dir "$scratch/$module"
done
leanc -UNDEBUG -I"$scratch/SharedFirst" -I"$scratch/SharedSecond" \
    "$backend/tests/shared_initialization.c" "$scratch/SharedFirst/libshared_first.a" \
    "$scratch/SharedSecond/libshared_second.a" -o "$scratch/shared_initialization"
test "$("$scratch/shared_initialization" </dev/null)" = "7 7"
LEANFRAN_TEST_SHARED_INIT_ERROR=1 "$scratch/shared_initialization" </dev/null

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
roots+=,Typed.floats,Typed.floatSum,Typed.floatMake,Typed.samples
roots+=,Typed.wrapText,Typed.wrapByte,Typed.wrapNat,Typed.wrapFloat,Typed.wrapPoint,Typed.bounded
roots+=,Typed.boundedByte,Typed.wrapped
"$compiler" --lang c generate --module-name PublicTypes --roots "$roots" --out-dir "$types"
"$compiler" --lang c build --out-dir "$types"

rejected() {
    local diagnostic=$1
    shift
    local status=0
    "$compiler" --lang c generate --module-name PublicTypes --out-dir "$scratch/collision" "$@" \
        >"$scratch/rejected" 2>&1 || status=$?
    test "$status" -eq 254
    grep -F "$diagnostic" "$scratch/rejected"
    test ! -e "$scratch/collision"
}

rejected 'C name collision: public_types_foo_bar' --roots Collision.fooBar,Collision.foo_bar
rejected 'C name collision: public_types_collision_fields.foo_bar' --roots Collision.echo
rejected 'unsupported parameter type' --roots Typed.unsupported
not_constructor='the Lean runtime does not represent it as a constructor object'
rejected "'Typed.taskGet' has an unsupported parameter type: unsupported type Task UInt8: $not_constructor" \
    --roots Typed.taskGet
rejected "'Typed.taskPure' has an unsupported result type: unsupported type Task UInt8: $not_constructor" \
    --roots Typed.taskPure
rejected "'Typed.thunkGet' has an unsupported parameter type: unsupported type Thunk UInt8: $not_constructor" \
    --roots Typed.thunkGet
rejected "unsupported type Task UInt8: $not_constructor (field Typed.Pending.task)" --roots Typed.pendingGet
rejected 'Checked.Undecidable.proof has no Decidable instance' --roots Checked.bad

renamed="$scratch/renamed"
"$compiler" --lang c generate --module-name PublicTypes --out-dir "$renamed" \
    --roots Collision.echo,Collision.fooBar,Collision.foo_bar \
    --rename Collision.fooBar=camel_case --rename Collision.Fields.fooBar=camel_case \
    --rename Collision.Fields=renamed_fields
grep -F 'lf_status public_types_camel_case(' "$renamed/public_types.h"
grep -F 'bool camel_case LF_LEAN("fooBar");' "$renamed/public_types.h"
grep -F 'typedef struct public_types_renamed_fields' "$renamed/public_types.h"
"$compiler" --lang c build --out-dir "$renamed"

types_args=(-I"$types" -UNDEBUG -Wall -Wextra -Werror "$backend/tests/types/roundtrip.c")
leanc "${types_args[@]}" "$types/libpublic_types.a" -o "$scratch/roundtrip"
"$scratch/roundtrip" </dev/null
mkdir -p "$scratch/oracle/LeanfranC"
lean -R "$types" -o "$scratch/oracle/LeanfranC/Json.olean" "$types/LeanfranC/Json.lean"
LEAN_PATH="$scratch/oracle:$PWD/.lake/build/lib/lean" \
    lean -DwarningAsError=true -R "$types" "$types/LeanfranExport/PublicTypes.lean"
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

handles="$scratch/handles"
"$compiler" --lang c generate --module-name ValueHandles --out-dir "$handles"
"$compiler" --lang c build --out-dir "$handles"
handles_args=(-I"$handles" -UNDEBUG -Wall -Wextra -Werror "$backend/tests/types/value_handles.c")
leanc "${handles_args[@]}" "$handles/libvalue_handles.a" -o "$scratch/value_handles"
"$scratch/value_handles" </dev/null
"$scratch/value_handles" --benchmark </dev/null

if [[ $(uname -s) == Linux ]]; then
    handles_source=("$handles/value_handles.c" "$handles/leanfran.c" "$handles/libvalue_handles.a")
    leanc "${handles_args[@]}" "${sanitizer[@]}" "${handles_source[@]}" -o "$scratch/value_handles_asan"
    "$scratch/value_handles_asan" </dev/null
    LEAN_CC=clang leanc "${handles_args[@]}" -fsanitize=thread -fno-omit-frame-pointer -no-pie \
        "${handles_source[@]}" -o "$scratch/value_handles_tsan"
    TSAN_OPTIONS=halt_on_error=1 "$scratch/value_handles_tsan" </dev/null
fi
