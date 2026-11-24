#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

module=LeanGoTest.ControlDepth
out=test-out/_generated/depth
mkdir -p "$out"
lake build leanfran-go oracle-control-depth
.lake/build/bin/leanfran-go module generate --module-name "$module" --roots "$module.run" \
    --main "$module.run" --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file "$out/main.go"
test -z "$(gofmt -l "$out/main.go")"
grep -Fq 'rt.TailCall(frame, tail_L_LeanGoTest_ControlDepth_evenStep,' "$out/main.go"
grep -Fq 'rt.TailCall(frame, tail_L_LeanGoTest_ControlDepth_oddStep,' "$out/main.go"
grep -Fq 'rt.TailCall(frame, tail_L_LeanGoTest_ControlDepth_chainMiddle,' "$out/main.go"
grep -Fq 'rt.TailCall(frame, tail_L_LeanGoTest_ControlDepth_chainEnd,' "$out/main.go"
sed -n '/^func core_L_LeanGoTest_ControlDepth_applyStep(/,/^}/p' "$out/main.go" |
    grep -F 'return rt.TailApply(frame,' > /dev/null
go vet "./$out"
CGO_ENABLED=0 go build -o "$out/run" "./$out"

compare() {
    local mode=$1 depth=$2
    (
        ulimit -s "$(ulimit -Hs)"
        .lake/build/bin/oracle-control-depth "$mode" "$depth"
    ) > "$out/c-$mode.out" 2> "$out/c-$mode.err"
    "$out/run" "$mode" "$depth" > "$out/go-$mode.out" 2> "$out/go-$mode.err"
    diff -u "$out/c-$mode.out" "$out/go-$mode.out"
    diff -u "$out/c-$mode.err" "$out/go-$mode.err"
}

compare chain 101
printf 'depth chain: C/Go n=101 => %s\n' "$(cat "$out/go-chain.out")"

for mode in self mutual cps; do
    compare "$mode" 101
    case "$mode" in
        self|cps) want=100000000 ;;
        mutual) want=250000000 ;;
    esac
    "$out/run" "$mode" 100000000 > "$out/deep-$mode.out"
    printf '%s\n' "$want" | diff -u - "$out/deep-$mode.out"
    printf 'depth %s: C/Go n=101 => %s, Go n=100000000 => %s\n' \
        "$mode" "$(cat "$out/go-$mode.out")" "$want"
done

compare non-tail 1000000
printf 'depth non-tail: C/Go n=1000000 => %s\n' "$(cat "$out/go-non-tail.out")"
