#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

root=$PWD
export LEANFRAN_GO_CLI="$root/.lake/build/bin/leanfran-go"
mkdir -p test-out
out=$(mktemp -d "$root/test-out/embed.XXXXXX")
trap 'rm -rf "$out"' EXIT
cp -R testdata/embed/. "$out"
go build -o "$out/leanfran" ./cmd/leanfran
cd "$out"

go get -tool github.com/conao3/leanfran-go/cmd/leanfran
go tool leanfran sync
go tool leanfran check --dir consumer
go vet ./...
go test ./...
test -z "$(gofmt -l .)"
go run ./oracle > go.out
workspace=.leanfran/workspace
types_module="LeanGoEmbed.B$(printf %s example.com/embed-fixture/types | od -An -tx1 | tr -d ' \n')"
consumer_module="LeanGoEmbed.B$(printf %s example.com/embed-fixture/consumer | od -An -tx1 | tr -d ' \n')"
{
    cat lean-dependency/Domain.lean "$workspace/LeanGoModels.lean"
    sed '/^import /d' "$workspace/${types_module/.//}.lean" "$workspace/${consumer_module/.//}.lean"
    printf '\ndef main : IO Unit := IO.println (%s.countTwice 7)\n' "$consumer_module"
} > Oracle.lean
lean -c oracle.c Oracle.lean
leanc -o native oracle.c
./native | diff -u - go.out
mkdir .leanfran/previous
snapshot() {
    for pkg in types consumer; do
        mkdir -p ".leanfran/previous/$pkg"
        cp "$pkg/"leanfran* ".leanfran/previous/$pkg/"
    done
}
unchanged() {
    for pkg in types consumer; do
        for file in ".leanfran/previous/$pkg/"*; do
            cmp "$file" "$pkg/${file##*/}"
        done
    done
}
snapshot
go tool leanfran sync
unchanged

mkdir tools
ln -s "$(command -v go)" tools/go
PATH="$out/tools" ./leanfran status
expect_failure() {
    local status=0
    "$@" > result.out 2> result.err || status=$?
    test "$status" = 1
}

list_stale() {
    expect_failure go tool leanfran status
    local expected
    for expected in "$@"; do
        grep -Eq "^example.com/embed-fixture/$expected:" result.out
    done
    test "$(wc -l < result.out)" -eq "$#"
}
check_edit() {
    local file=$1 old=$2 new=$3
    shift 3
    cp "$file" original
    sed -i "s|$old|$new|" "$file"
    list_stale "$@"
    mv original "$file"
}
check_edit consumer/consumer.go 'alternate := domainEnabled' 'alternate := false' consumer
check_edit types/types.go 'Std.Data.HashMap' 'Std' types consumer
check_edit types/types.go ':= ⟨value⟩' ':= { value := value }' types consumer
check_edit types/types.go 'min_len=2' 'min_len=3' types consumer
check_edit leanfran.config.json '"\."' '"types", "consumer"' types consumer
version=$("$LEANFRAN_GO_CLI" --generator-version)
check_edit types/leanfran.json "\"generator_version\": $version" '"generator_version": 0' types

mv consumer/leanfran_funcs_gen.go missing
list_stale consumer
mv missing consumer/leanfran_funcs_gen.go

cp consumer/consumer.go original
sed -i 's/def alternate := domainEnabled/theorem alternateImpossible : False := by omega/' consumer/consumer.go
expect_failure go tool leanfran sync
omega_col=$(awk '/theorem alternateImpossible/ { print index($0, "omega") }' consumer/consumer.go)
grep -Eq "consumer/consumer.go:8:${omega_col}: error: \\(lean block example.com/embed-fixture/consumer, Lean 3:.*omega could not prove" result.err
unchanged
go test ./...
sed -i 's/theorem alternateImpossible : False := by omega/def alternate :=)/' consumer/consumer.go
expect_failure go tool leanfran sync
syntax_col=$(awk '/def alternate :=\)/ { print index($0, "def alternate :=)") + length("def alternate :=") }' consumer/consumer.go)
grep -Eq "consumer/consumer.go:8:${syntax_col}: error: \\(lean block example.com/embed-fixture/consumer, Lean 3:.*unexpected token" result.err
unchanged
mv original consumer/consumer.go

cp types/types.go original
sed -i 's/List \[\]int/List map[string]int/' types/types.go
expect_failure go tool leanfran status
grep -Eq 'Record.List: unsupported field type map\[string\]int' result.err
mv original types/types.go
unchanged

cat > wrong-compiler <<'COMPILER'
#!/usr/bin/env bash
printf '0\n'
COMPILER
chmod +x wrong-compiler
expect_failure go tool leanfran sync --leanfran-go ./wrong-compiler
grep -Eq 'compiler generator version 0, expected' result.err
unchanged

mv consumer/consumer.go consumer/consumer.go.saved
mv consumer/consumer_test.go consumer/consumer_test.go.saved
expect_failure go tool leanfran status
grep -Eq '^example.com/embed-fixture/consumer: removed block' result.out
go tool leanfran sync
for file in .leanfran/previous/consumer/*; do
    test ! -e "consumer/${file##*/}"
done
go tool leanfran status
printf 'embed integration passes: 2 blocks, 8 freshness changes, 2 mapped Lean errors, 1 model error and removal\n'
