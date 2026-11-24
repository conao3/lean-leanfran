#!/usr/bin/env bash
set -euo pipefail

backend="$(cd "$(dirname "$0")/../../langs/C" && pwd)"
compiler="$backend/.lake/build/bin/leanfran-c"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/link.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

cd "$backend/tests/cases"
reject() {
    local expected=$1 status=0
    shift
    "$compiler" generate --out-dir "$scratch/invalid" "$@" >"$scratch/diagnostics" 2>&1 || status=$?
    test "$status" -eq 254
    grep -F -- "$expected" "$scratch/diagnostics"
    test ! -e "$scratch/invalid"
}

reject "'Checks.dependsOnSorry' depends on sorryAx" \
    --module-name Examples.Checks --roots Checks.dependsOnSorry
reject "go:foreign.Increment" --module-name Examples.ForeignExtern --roots callsForeign
reject "Examples.LeanImport -> Examples.JsonDependency -> Lean.Data.Json" \
    --module-name Examples.LeanImport

"$compiler" generate --module-name Examples.Checks \
    --roots Checks.dependsOnSorry --allow-sorry --out-dir "$scratch/sorry" 2>"$scratch/warning"
grep -F "warning: 'Checks.dependsOnSorry' depends on sorryAx" "$scratch/warning"

extern="$scratch/extern"
"$compiler" generate --module-name Examples.Checks --roots Checks.withExtern --out-dir "$extern"
printf '%s\n' leanfran_test_increment | diff -u - "$extern/checks.externs.txt"
grep -F 'Checks.alternative -> ' "$extern/checks.implemented-by.txt"
grep -F 'Checks.implementation' "$extern/checks.implemented-by.txt"
"$compiler" build --out-dir "$extern"

lean_import="$scratch/import"
"$compiler" generate --module-name Examples.LeanImport --allow-lean-import --out-dir "$lean_import"
"$compiler" build --out-dir "$lean_import"

out="$scratch/static"
shared="$scratch/shared output"
"$compiler" generate --module-name Examples.PublicApi --out-dir "$out"
"$compiler" generate --module-name Examples.PublicApi --out-dir "$shared"
test ! -s "$out/public_api.externs.txt"
"$compiler" build --out-dir "$out"
"$compiler" build --shared --out-dir "$shared"
if [[ $(uname -s) == Darwin ]]; then
    test -f "$shared/libpublic_api.dylib"
else
    test -f "$shared/libpublic_api.so"
fi

cd "$backend/tests/link"
link_from_pc() {
    local pc=$1
    shift
    local flags
    flags=$(PKG_CONFIG_PATH="${pc%/*}" pkg-config --cflags --libs "$(basename "$pc" .pc)")
    eval '"$@" '"$flags"
}

link_from_pc "$extern/checks.pc" cc -std=c11 extern.c -o "$scratch/test-extern"
"$scratch/test-extern"
link_from_pc "$lean_import/lean_import.pc" cc -std=c11 lean_import.c -o "$scratch/test-import"
"$scratch/test-import"

include="$(lean --print-prefix)/include"
for cc in gcc clang; do
    for source in public_api leanfran; do
        "$cc" -std=c11 -Wall -Wextra -Werror -pedantic -isystem "$include" \
            -c "$out/$source.c" -o "$scratch/$source.o"
    done
    link_from_pc "$out/public_api.pc" "$cc" -std=c11 -Wall -Wextra -Werror -pedantic \
        main.c -o "$scratch/test-cc"
    "$scratch/test-cc"
done
link_from_pc "$out/public_api.pc" g++ -std=c++17 -Wall -Wextra -Werror -pedantic \
    -x c++ main.c -x none -o "$scratch/test-cpp"
"$scratch/test-cpp"

for bindings in "$out" "$shared"; do
    link_from_pc "$bindings/public_api.pc" cc -std=c11 main.c -o "$scratch/test-pc"
    "$scratch/test-pc"
    make check "BINDINGS=${bindings// /\\ }/public_api.mk" "OUTPUT=$scratch/test-make"
    cmake -S . -B "$bindings/consumer" "-Dpublic_api_DIR=$bindings"
    cmake --build "$bindings/consumer"
    "$bindings/consumer/consumer"
done
