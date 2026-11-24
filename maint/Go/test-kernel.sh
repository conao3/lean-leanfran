#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

lake build leanfran-go
out="$PWD/test-out/kernel"
generated=test-out/_generated/kernel
mkdir -p "$out" "$generated"
lean --root=testdata/kernel -o "$out/Kernel.olean" -c "$out/Kernel.c" testdata/kernel/Kernel.lean
LEAN_PATH="$out" lean --root=testdata/kernel -c "$out/Oracle.c" testdata/kernel/Oracle.lean
leanc -O2 -o "$out/oracle" "$out/Kernel.c" "$out/Oracle.c"
.lake/build/bin/leanfran-go module generate --module-name Kernel --search-path "$out" --output-dir "$generated"
cp testdata/kernel/*_test.go "$generated/"
go vet "./$generated"
LEANFRAN_KERNEL_ORACLE="$out/oracle" go test -count=1 "./$generated"
LEANFRAN_KERNEL_ORACLE="$out/oracle" CGO_ENABLED=1 go test -race -count=1 "./$generated" -run 'TestConcurrentValues|TestSharedValues|TestValueScope'

typecheck="$out/_typecheck"
mkdir -p "$typecheck"
cat >"$typecheck/wrong-type.go" <<'GO'
package typecheck

import (
    "github.com/conao3/leanfran-go"
    "github.com/conao3/leanfran-go/test-out/_generated/kernel"
)

func wrongType(v leanfran.Value[kernel.Actor], command leanfran.Value[kernel.Command]) {
    kernel.TransitionValue(v.Borrow(), v.Borrow(), command.Borrow())
}
GO
if go test "$typecheck/wrong-type.go" >"$out/wrong-type.txt" 2>&1; then
    printf 'TransitionValue accepted an Actor in place of a Snapshot\n' >&2
    exit 1
fi
grep -F 'as leanfran.ValueInput[kernel.Snapshot]' "$out/wrong-type.txt"
