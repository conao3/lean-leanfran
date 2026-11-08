#!/usr/bin/env bash
# lean! checks beyond the tests of the crate: the cache is used without Lean, LEAN_RUST_OFFLINE=1
# builds from the cache, a wrong proof stops the build at the Rust file and line, and a block
# missing from the cache is listed under LEAN_RUST_OFFLINE=1.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
export LEAN_RUST_CLI="$root/.lake/build/bin/lean-rust"
cargo build -q -p lean-rust-embed-test

marker=$(mktemp)
touch tests/embed/src/lib.rs
LEAN_RUST_CLI=/nonexistent/lean-rust cargo build -q -p lean-rust-embed-test
LEAN_RUST_OFFLINE=1 cargo build -q -p lean-rust-embed-test
written=$(find tests/embed/.lean-rust tests/embed/lean -path '*/.lake' -prune -o -type f -newer "$marker" -print)
rm -f "$marker"
if [ -n "$written" ]; then
  echo "embed-test: a cached build wrote into the source tree: $written" >&2
  exit 1
fi
echo "embed-test: cached build without lean-rust and with LEAN_RUST_OFFLINE=1"

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
lean-rust = { path = "$root/crates/lean-rust" }

[build-dependencies]
lean-rust-build = { path = "$root/crates/lean-rust-build" }

[workspace]
TOML
cat > "$fixture/build.rs" <<'RS'
fn main() {
    lean_rust_build::Builder::new().compile().unwrap();
}
RS
export CARGO_TARGET_DIR="$root/test-out/fixtures/target"
if LEAN_RUST_OFFLINE=1 cargo build -q --manifest-path "$fixture/Cargo.toml" > "$fixture/offline.log" 2>&1; then
  echo "embed-test: LEAN_RUST_OFFLINE=1 built without a cache" >&2
  exit 1
fi
grep -q "LEAN_RUST_OFFLINE=1 and these lean! blocks are not in" "$fixture/offline.log"
grep -q "src/lib.rs (crate::bad::" "$fixture/offline.log"
echo "embed-test: LEAN_RUST_OFFLINE=1 lists the block missing from the cache"
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
