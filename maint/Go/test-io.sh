#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

export LEAN_BACKTRACE=0
export LEANFRAN_GO_IO_VALUE='parent environment'
unset LEANFRAN_GO_IO_UNSET

lake build leanfran-go oracle-io
mkdir -p test-out
compiler="$PWD/.lake/build/bin/leanfran-go"
oracle="$PWD/.lake/build/bin/oracle-io"
root=LeanGoTest.Io.run
fixture_root=$(mktemp -d "$PWD/test-out/_io.XXXXXX")
trap 'rm -rf -- "$fixture_root"' EXIT

"$compiler" module generate --module-name LeanGoTest.Io --roots "$root" --main "$root" \
    --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file "$fixture_root/main.go"
test -z "$(gofmt -l "$fixture_root/main.go")"
go vet "$fixture_root/main.go"
CGO_ENABLED=0 go build -o "$fixture_root/io-go" "$fixture_root/main.go"

mkdir -p "$fixture_root/initial/existing-dir" "$fixture_root/initial/tmp"
printf 'initial content\n' > "$fixture_root/initial/initial.txt"
printf 'nested content\n' > "$fixture_root/initial/existing-dir/file.txt"
printf '%s\n' '#!/bin/sh' 'printf "%s:%s" "$LEANFRAN_GO_IO_CHILD" "$LEANFRAN_GO_IO_VALUE"' > "$fixture_root/initial/existing-dir/look-up"
chmod u+x "$fixture_root/initial/existing-dir/look-up"
printf 'unreadable\n' > "$fixture_root/initial/protected.txt"
ln -s initial.txt "$fixture_root/initial/initial-link"
printf 'first line\nabcdef\n' > "$fixture_root/stdin"
fixtures_matched=0
run_fixture() {
    local case_name=$1 expected_status=$2 actual_status=0 backend
    local command
    for backend in c go; do
        cp -a "$fixture_root/initial" "$fixture_root/work"
        chmod 000 "$fixture_root/work/protected.txt"
        if [[ -r "$fixture_root/work/protected.txt" ]]; then
            echo "The permission fixture requires running as a user without read access to mode-000 files." >&2
            exit 1
        fi
        if [[ $backend == c ]]; then
            command=$oracle
        else
            command="$fixture_root/io-go"
        fi
        actual_status=0
        (
            cd "$fixture_root/work"
            TMPDIR="$PWD/tmp" timeout --kill-after=2s 25s "$command" "$case_name"
        ) < "$fixture_root/stdin" > "$fixture_root/$backend.out" 2> "$fixture_root/$backend.err" || actual_status=$?
        if [[ $actual_status != "$expected_status" ]]; then
            cat "$fixture_root/$backend.out" "$fixture_root/$backend.err" >&2
            echo "$case_name: $backend exited $actual_status, expected $expected_status" >&2
            exit 1
        fi
        mv "$fixture_root/work" "$fixture_root/$backend.tree"
        chmod u+r "$fixture_root/$backend.tree/protected.txt"
    done
    diff -au "$fixture_root/c.out" "$fixture_root/go.out"
    diff -au "$fixture_root/c.err" "$fixture_root/go.err"
    diff -r --no-dereference "$fixture_root/c.tree" "$fixture_root/go.tree"
    echo "io: $case_name matches C (stdout, stderr, status $actual_status, files)"
    fixtures_matched=$((fixtures_matched + 1))
    rm -rf -- "$fixture_root/c.tree" "$fixture_root/go.tree"
}

for fixture in streams files file-errors environment processes large-process tasks arrays; do
    run_fixture "$fixture" 0
done
run_fixture uncaught 1
run_fixture exit 7
run_fixture force-exit 8
echo "io: $fixtures_matched fixtures matched"

status=0
timeout --kill-after=2s 25s "$fixture_root/io-go" pending-promise \
    < "$fixture_root/stdin" > "$fixture_root/pending.out" 2> "$fixture_root/pending.err" || status=$?
if [[ $status != 1 ]]; then
    echo "pending-promise: Go exited $status, expected 1" >&2
    exit 1
fi
diff -u /dev/null "$fixture_root/pending.out"
printf 'INTERNAL PANIC: Cannot wait on an unresolved promise in synchronous execution\n' |
    diff -u - "$fixture_root/pending.err"
echo 'io: pending-promise reports an internal panic and exits 1 (Go only)'
