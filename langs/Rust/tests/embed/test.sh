#!/usr/bin/env bash
# lean! checks beyond the tests of the crate: the cache is used without Lean, LEANFRAN_OFFLINE=1
# builds from the cache, a wrong proof stops the build at the Rust file and line, and a block
# missing from the cache is listed under LEANFRAN_OFFLINE=1. An unchanged build stays fresh.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
export LEANFRAN_CLI="$root/.lake/build/bin/leanfran"
cargo build -q -p leanfran-embed-test

marker=$(mktemp)
touch tests/embed/src/lib.rs
LEANFRAN_CLI=/nonexistent/leanfran cargo build -q -p leanfran-embed-test
LEANFRAN_OFFLINE=1 cargo build -q -p leanfran-embed-test
written=$(find tests/embed/.leanfran tests/embed/lean -path '*/.lake' -prune -o -type f -newer "$marker" -print)
rm -f "$marker"
if [ -n "$written" ]; then
  echo "embed-test: a cached build wrote into the source tree: $written" >&2
  exit 1
fi
echo "embed-test: cached build without leanfran and with LEANFRAN_OFFLINE=1"

fresh_log=$(mktemp)
if ! LEANFRAN_OFFLINE=1 cargo build -vv -p leanfran-embed-test > "$fresh_log" 2>&1 ||
    ! grep -q "Fresh leanfran-embed-test " "$fresh_log"; then
  echo "embed-test: the unchanged crate was not fresh" >&2
  sed -n '/leanfran-embed-test/p' "$fresh_log" >&2
  rm -f "$fresh_log"
  exit 1
fi
rm -f "$fresh_log"
echo "embed-test: an unchanged build stays fresh without a proof lockfile"

fixture=test-out/fixtures/bad-proof
rm -rf "$fixture"
mkdir -p "$fixture"
cp -r tests/embed/fixtures/bad-proof/src "$fixture/"
cat > "$fixture/Cargo.toml" <<TOML
[package]
name = "bad-proof"
version = "0.1.0"
edition = "2021"

[dependencies]
leanfran = { path = "$root/crates/leanfran" }

[build-dependencies]
leanfran-build = { path = "$root/crates/leanfran-build" }

[workspace]
TOML
cat > "$fixture/build.rs" <<'RS'
fn main() {
    leanfran_build::Builder::new().compile().unwrap();
}
RS
export CARGO_TARGET_DIR="$root/test-out/fixtures/target"
local_imports=test-out/fixtures/local-imports
rm -rf "$local_imports"
mkdir -p "$local_imports"
cp -r tests/embed/fixtures/local-imports/. "$local_imports/"
sed 's/name = "bad-proof"/name = "local-imports"/' "$fixture/Cargo.toml" > "$local_imports/Cargo.toml"
cp "$fixture/build.rs" "$local_imports/"

if LEANFRAN_OFFLINE=1 cargo build -q --manifest-path "$fixture/Cargo.toml" > "$fixture/offline.log" 2>&1; then
  echo "embed-test: LEANFRAN_OFFLINE=1 built without a cache" >&2
  exit 1
fi
grep -q "LEANFRAN_OFFLINE=1 and these lean! blocks are not in" "$fixture/offline.log"
grep -q "src/lib.rs (crate::bad::" "$fixture/offline.log"
grep -q "Restore the matching cache, or unset LEANFRAN_OFFLINE" "$fixture/offline.log"
echo "embed-test: LEANFRAN_OFFLINE=1 lists the block missing from the cache"
if cargo build -q --manifest-path "$fixture/Cargo.toml" > "$fixture/build.log" 2>&1; then
  echo "embed-test: the wrong proof was accepted" >&2
  exit 1
fi
grep -q "src/lib.rs:7:22: error: omega could not prove the goal" "$fixture/build.log"
echo "embed-test: the wrong proof stops the build at src/lib.rs:7:22"

rm "$fixture/build.rs"
if cargo build -q --manifest-path "$fixture/Cargo.toml" > "$fixture/no-build.log" 2>&1; then
  echo "embed-test: lean! compiled without a build script" >&2
  exit 1
fi
grep -q "lean!: the crate has no build script" "$fixture/no-build.log"
echo "embed-test: lean! without a build script reports how to add one"

manifest="$local_imports/Cargo.toml"
mkdir "$local_imports/lean/Proofs"
printf 'theorem correct : True := True.intro\n' > "$local_imports/lean/Proofs/Answer.lean"
mkdir -p "$local_imports/lean/downloaded/dep/Nested"
printf 'def downloaded := 0\n' > "$local_imports/lean/downloaded/dep/Nested/Values.lean"
mkdir "$local_imports/lean/MyApp"
printf 'not valid Lean\n' > "$local_imports/lean/MyApp/Std.lean"
test "$(cargo run -q --manifest-path "$manifest")" = 11
mv "$local_imports/lean/downloaded" "$local_imports/downloaded"
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 11
echo "embed-test: a checkout without downloaded Lean packages reuses the cache"
printf 'theorem correct : True := by trivial\n' > "$local_imports/lean/Proofs/Answer.lean"
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 11
echo "embed-test: a proof-only edit reuses the local-import cache"
printf 'still not valid Lean\n' > "$local_imports/lean/MyApp/Std.lean"
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 11
echo "embed-test: a file with the same suffix as an external import does not affect the cache"
printf 'def nestedValue : UInt32 := 2\n' > "$local_imports/lean/local/Nested/Values.lean"
if LEANFRAN_OFFLINE=1 cargo build -q --manifest-path "$manifest" > "$local_imports/offline.log" 2>&1; then
  echo "embed-test: a stale local Lean dependency was accepted offline" >&2
  exit 1
fi
grep -q "LEANFRAN_OFFLINE=1 and these lean! blocks are not in" "$local_imports/offline.log"
test "$(cargo run -q --manifest-path "$manifest")" = 12
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 12
echo "embed-test: changing a transitive local Lean import rejects the old offline cache and regenerates online"

printf 'def dependencyValue : UInt32 := 1\n' > "$local_imports/lean/dep/Dependency.lean"
test "$(cargo run -q --manifest-path "$manifest")" = 13
echo "embed-test: changing an imported Lake path dependency regenerates Rust"

mv "$local_imports/lean/local" "$local_imports/lean-src"
ln -s ../lean-src "$local_imports/lean/local"
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 13
printf 'def nestedValue : UInt32 := 3\n' > "$local_imports/lean-src/Nested/Values.lean"
test "$(cargo run -q --manifest-path "$manifest")" = 14
echo "embed-test: changing a Lean import through a symlinked source directory regenerates Rust"

mkdir "$local_imports/lean/new-dep"
cp "$local_imports/lean/dep/"{Dependency.lean,lakefile.toml} "$local_imports/lean/new-dep/"
sed 's/path = "dep"/path = "new-dep"/' "$local_imports/lean/lakefile.toml" > "$local_imports/lean/lakefile.new"
mv "$local_imports/lean/lakefile.new" "$local_imports/lean/lakefile.toml"
test "$(cargo run -q --manifest-path "$manifest")" = 14
printf 'def dependencyValue : UInt32 := 2\n' > "$local_imports/lean/dep/Dependency.lean"
if LEANFRAN_OFFLINE=1 cargo build -q --manifest-path "$manifest" > "$local_imports/offline.log" 2>&1; then
  echo "embed-test: a stale cache for the locked Lake dependency was accepted offline" >&2
  exit 1
fi
grep -q "LEANFRAN_OFFLINE=1 and these lean! blocks are not in" "$local_imports/offline.log"
test "$(cargo run -q --manifest-path "$manifest")" = 15
(cd "$local_imports/lean" && lake update dependency)
test "$(cargo run -q --manifest-path "$manifest")" = 14
echo "embed-test: Rust tracks the locked dependency before and after lake update"

printf '\ndef identity (a : α) := a\n' >> "$local_imports/lean/new-dep/Dependency.lean"
test "$(cargo run -q --manifest-path "$manifest")" = 14
sed '/^name = "dependency"$/a leanOptions = { autoImplicit = false }' "$local_imports/lean/new-dep/lakefile.toml" > "$local_imports/lean/new-dep/lakefile.new"
mv "$local_imports/lean/new-dep/lakefile.new" "$local_imports/lean/new-dep/lakefile.toml"
if cargo build -q --manifest-path "$manifest" > "$local_imports/options.log" 2>&1; then
  echo "embed-test: Rust reused a cache generated with old dependency options" >&2
  exit 1
fi
grep -Fq 'Unknown identifier `α`' "$local_imports/options.log"
echo "embed-test: changing a local dependency lakefile invalidates Rust"
