#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
backend="$root/langs/C"
compiler="$backend/.lake/build/bin/leanfran-c"
go_backend="$root/langs/Go"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/schema.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

cd "$backend/tests/types"
for spec in schema:Schema.sample range:Checked.echo mixed:Typed.mixed; do
    name=${spec%%:*}
    "$compiler" generate --module-name PublicTypes --roots "${spec#*:}" \
        --prefix "$name" --out-dir "$scratch/$name"
done

cd "$go_backend"
lake build leanfran-go
.lake/build/bin/leanfran-go module generate --module-name PublicTypes \
    --search-path "$backend/tests/types/.lake/build/lib/lean" \
    --roots Schema.sample Checked.echo Typed.mixed --package schematest --output-dir "$scratch" --output text

cd "$scratch"
cp "$backend/tests/types/schema_test.go" .
go mod init leanfran-c-schema
go mod edit -require github.com/conao3/leanfran-go@v0.0.0 \
    -replace "github.com/conao3/leanfran-go=$go_backend"
GOTOOLCHAIN=local GOPROXY=off go test -mod=mod -v .
