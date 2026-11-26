#!/usr/bin/env bash
# lean! checks beyond the tests of the crate: the cache is used without Lean, LEANFRAN_OFFLINE=1
# builds from the cache, a wrong proof stops the build at the Rust file and line, and a block
# missing from the cache is listed under LEANFRAN_OFFLINE=1.
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
test "$(cargo run -q --manifest-path "$manifest")" = 11
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 11
printf 'def nestedValue : UInt32 := 2\n' > "$local_imports/lean/local/Nested/Values.lean"
if LEANFRAN_OFFLINE=1 cargo build -q --manifest-path "$manifest" > "$local_imports/offline.log" 2>&1; then
  echo "embed-test: a stale local Lean dependency was accepted offline" >&2
  exit 1
fi
grep -q "LEANFRAN_OFFLINE=1 and these lean! blocks are not in" "$local_imports/offline.log"
test "$(cargo run -q --manifest-path "$manifest")" = 12
test "$(LEANFRAN_OFFLINE=1 LEANFRAN_CLI=/nonexistent/leanfran cargo run -q --manifest-path "$manifest")" = 12
echo "embed-test: changing a transitive local Lean import rejects the old offline cache and regenerates online"
