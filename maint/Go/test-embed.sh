#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

root=$PWD
export LEANFRAN_CLI="$root/../../.lake/build/bin/leanfran"
mkdir -p test-out
out=$(mktemp -d "$root/test-out/embed.XXXXXX")
trap 'rm -rf "$out"' EXIT
cp -R testdata/embed/. "$out"
cd "$out"

export PATH="${LEANFRAN_CLI%/*}:$PATH"
export GOBIN="$out/bin"
tool=github.com/conao3/leanfran-go/cmd/leanfran-go
status=0
leanfran --lang go sync > result.out 2> result.err || status=$?
test "$status" = 255
grep -Fq "go get -tool $tool" result.err
go get -tool "$tool"
test ! -e "$GOBIN/leanfran"
test "$(command -v leanfran)" = "$LEANFRAN_CLI"
LEANFRAN_CLI=./missing-compiler leanfran --lang go sync
leanfran --lang go check --dir consumer
go vet ./...
go test ./...
test -z "$(gofmt -l .)"
go run ./oracle > go.out
workspace=.leanfran/go/workspace
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
    cp leanfran.manifest.json .leanfran/previous/
    for pkg in types consumer; do
        mkdir -p ".leanfran/previous/$pkg"
        cp "$pkg/"leanfran* ".leanfran/previous/$pkg/"
    done
}
unchanged() {
    cmp .leanfran/previous/leanfran.manifest.json leanfran.manifest.json
    for pkg in types consumer; do
        for file in ".leanfran/previous/$pkg/"*; do
            cmp "$file" "$pkg/${file##*/}"
        done
    done
}
snapshot
leanfran --lang go sync
unchanged

mkdir tools
ln -s "$(command -v go)" tools/go
PATH="$out/tools" "$LEANFRAN_CLI" --lang go status
expect_failure() {
    local expected=$1 status=0
    shift
    "$@" > result.out 2> result.err || status=$?
    test "$status" = "$expected"
}

list_stale() {
    expect_failure 1 leanfran --lang go status
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
version=$("$LEANFRAN_CLI" --lang go --generator-version)
check_edit leanfran.manifest.json "\"compiler\": \"$version/" '"compiler": "0/' types consumer

mv consumer/leanfran_funcs_gen.go missing
list_stale consumer
mv missing consumer/leanfran_funcs_gen.go

cp consumer/consumer.go original
sed -i 's/def alternate := domainEnabled/theorem alternateImpossible : False := by omega/' consumer/consumer.go
expect_failure 254 leanfran --lang go sync
omega_col=$(awk '/theorem alternateImpossible/ { print index($0, "omega") }' consumer/consumer.go)
grep -Eq "consumer/consumer.go:8:${omega_col}: error: \\(lean block example.com/embed-fixture/consumer, Lean 3:.*omega could not prove" result.err
test "$(grep -c '^trace:' result.err)" = 0
expect_failure 254 leanfran --lang go check --verbose
grep -q '^trace:' result.err
grep -Eq "consumer/consumer.go:8:${omega_col}: error: \\(lean block example.com/embed-fixture/consumer, Lean 3:.*omega could not prove" result.err
unchanged
go test ./...
sed -i 's/theorem alternateImpossible : False := by omega/def alternate :=)/' consumer/consumer.go
expect_failure 254 leanfran --lang go sync
syntax_col=$(awk '/def alternate :=\)/ { print index($0, "def alternate :=)") + length("def alternate :=") }' consumer/consumer.go)
grep -Eq "consumer/consumer.go:8:${syntax_col}: error: \\(lean block example.com/embed-fixture/consumer, Lean 3:.*unexpected token" result.err
unchanged
mv original consumer/consumer.go

cp types/types.go original
sed -i 's/List \[\]int/List map[string]int/' types/types.go
expect_failure 254 leanfran --lang go status
grep -Eq 'Record.List: unsupported field type map\[string\]int' result.err
mv original types/types.go
unchanged

export REAL_GO="$(command -v go)"
mkdir test-bin
cat > test-bin/go <<'GO'
#!/usr/bin/env bash
if [[ "$1" == tool && "$2" == github.com/conao3/leanfran-go/cmd/leanfran-go ]]; then
    export "$WRONG_VAR=$WRONG_VERSION"
fi
exec "$REAL_GO" "$@"
GO
chmod +x test-bin/go
release=$("$LEANFRAN_CLI" --lang go --version)
lean=$("$LEANFRAN_CLI" --lang go --lean-version)
for mode in sync check; do
    expect_failure 255 env PATH="$out/test-bin:$PATH" WRONG_VAR=LEANFRAN_VERSION WRONG_VERSION=9.9.9 leanfran --lang go "$mode"
    grep -Fq "compiler release version \"9.9.9\", expected $release" result.err
    grep -Fq "update the Go module to the compiler's release" result.err
    expect_failure 255 env PATH="$out/test-bin:$PATH" WRONG_VAR=LEANFRAN_LEAN_VERSION WRONG_VERSION=9.9.9 leanfran --lang go "$mode"
    grep -Fq "compiler Lean version \"9.9.9\", expected $lean" result.err
    grep -Fq "install the compiler of this release with nix profile install 'github:conao3/lean-leanfran/v$release#leanfran'" result.err
done
expect_failure 255 env PATH="$out/test-bin:$PATH" WRONG_VAR=LEANFRAN_GENERATOR_VERSION WRONG_VERSION=0 leanfran --lang go sync
grep -Fq "compiler generator version \"0\", expected $version" result.err
unchanged

mv consumer/consumer.go consumer/consumer.go.saved
mv consumer/consumer_test.go consumer/consumer_test.go.saved
expect_failure 1 leanfran --lang go status
grep -Eq '^example.com/embed-fixture/consumer: removed$' result.out
leanfran --lang go sync
for file in .leanfran/previous/consumer/*; do
    test ! -e "consumer/${file##*/}"
done
leanfran --lang go status
printf 'embed integration passes: 2 blocks, freshness, mapped diagnostics, trace verbosity, compiler installation and version checks, model errors, and removal\n'
