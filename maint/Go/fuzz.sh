#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

if (( $# > 2 )); then
    echo 'Usage: fuzz.sh [SEED] [N]' >&2
    exit 2
fi
seed=${1-1}
count=${2-2000}
out=test-out/fuzz
mkdir -p "$out"
run=$(mktemp -d "$out/run.XXXXXXXX")
trap 'rm -r "$run"' EXIT
go run ../../maint/Go/fuzz-gen/main.go "$seed" "$count" > "$run/rows.tsv"

lake --dir ../.. build leanfran
lake build oracle-fuzz
../../.lake/build/bin/leanfran --lang go module generate --module-name LeanGoTest.FuzzMain \
    --roots main --main main --search-path .lake/build/lib/lean --internal-only \
    --output text --output-file "$run/main.go"
test -z "$(gofmt -l "$run/main.go")"
go vet "$run/main.go"
CGO_ENABLED=0 go build -o "$run/fuzz-go" "$run/main.go"

native_status=0
go_status=0
LEAN_BACKTRACE=0 .lake/build/bin/oracle-fuzz < "$run/rows.tsv" \
    > "$run/c.out" 2> "$run/c.err" || native_status=$?
"$run/fuzz-go" < "$run/rows.tsv" > "$run/go.out" 2> "$run/go.err" || go_status=$?
if (( native_status == 0 && go_status == 0 )) &&
    cmp -s "$run/c.out" "$run/go.out" && cmp -s "$run/c.err" "$run/go.err"; then
    printf 'fuzz seed=%s: %s rows match\n' "$seed" "$(wc -l < "$run/rows.tsv")"
    exit 0
fi

printf 'fuzz seed=%s N=%s: C exit=%s, Go exit=%s\n' "$seed" "$count" "$native_status" "$go_status" >&2
cat "$run/c.err" "$run/go.err" >&2
exec 3< "$run/c.out" 4< "$run/go.out"
line=0
while IFS= read -r row; do
    line=$((line + 1))
    c_end=0
    go_end=0
    IFS= read -r c_line <&3 || c_end=1
    IFS= read -r go_line <&4 || go_end=1
    if (( c_end || go_end )) || [[ "$c_line" != "$go_line" ]]; then
        printf 'Input row %d: %s\nC: %s\nGo: %s\n' "$line" "$row" "$c_line" "$go_line" >&2
        exit 1
    fi
done < "$run/rows.tsv"
echo 'Outputs have extra lines or a program failed after processing the input.' >&2
exit 1
