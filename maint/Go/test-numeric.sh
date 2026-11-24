#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LEAN_BACKTRACE=0
cd "$(dirname "$0")/../../langs/Go"

mkdir -p test-out/_generated
tmp=$(mktemp -d "$PWD/test-out/_generated/numeric.XXXXXXXX")
trap 'rm -r "$tmp"' EXIT

lean --stdin > "$tmp/externs.tsv" <<'LEAN'
import Lean
open Lean

unsafe def numericExterns : IO Unit := do
  enableInitializersExecution
  let env ← importModules #[{module := `Init}] {} (loadExts := true)
  let types := ["Nat", "Int", "UInt8", "UInt16", "UInt32", "UInt64", "USize",
    "Int8", "Int16", "Int32", "Int64", "ISize", "Float", "Float32", "Bool", "Char"]
  for (name, info) in env.constants.toList.mergeSort (fun a b => a.1.toString ≤ b.1.toString) do
    if types.contains (name.toString.splitOn ".").head! then
      if let some symbol := getExternNameFor env `c name then
        IO.println s!"{name}\t{symbol}\t{info.type}"
#eval numericExterns
LEAN

go run ../../maint/Go/numeric/main.go prepare "$tmp"
mkdir "$tmp/LeanGoTest"
cp LeanGoTest/{NumericOracle,NumericOracleMain}.lean "$tmp/LeanGoTest/"
(
    cd "$tmp"
    export LEAN_PATH="$tmp"
    for module in NumericOracle NumericOracleMain; do
        source="LeanGoTest/$module"
        lean -o "$source.olean" -c "$source.c" "$source.lean"
    done
    lean -c NumericDispatch.c NumericDispatch.lean
    leanc -O2 -o oracle LeanGoTest/{NumericOracle,NumericOracleMain}.c NumericDispatch.c
)
gofmt -w "$tmp/dispatch.go"
go vet "$tmp/dispatch.go"
CGO_ENABLED=0 go build -o "$tmp/runtime" "$tmp/dispatch.go"

for backend in oracle runtime; do
    if ! "$tmp/$backend" < "$tmp/input" > "$tmp/$backend.out"; then
        printf '%s failed on input ' "$backend" >&2
        sed -n "$(( $(wc -l < "$tmp/$backend.out") + 1 ))p" "$tmp/input" >&2
        exit 1
    fi
done
go run ../../maint/Go/numeric/main.go compare "$tmp"

panic_count=0
while IFS= read -r input; do
    for backend in oracle runtime; do
        status=0
        "$tmp/$backend" <<< "$input" > "$tmp/$backend-panic.out" 2> "$tmp/$backend-panic.err" || status=$?
        if [[ "$status" != 1 ]]; then
            printf '%s exited %s for %s, expected 1\n' "$backend" "$status" "$input" >&2
            exit 1
        fi
    done
    diff -u "$tmp/oracle-panic.out" "$tmp/runtime-panic.out"
    diff -u "$tmp/oracle-panic.err" "$tmp/runtime-panic.err"
    ((++panic_count))
done < "$tmp/panic-input"
printf 'numeric panics: %d byte-identical\n' "$panic_count"
