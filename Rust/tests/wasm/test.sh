#!/usr/bin/env bash
# Builds tests/wasm for wasm32-unknown-unknown and runs its checks in node, through the
# WebAssembly API without imports.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
export LEANFRAN_CLI="$root/.lake/build/bin/leanfran"
cargo build -q -p leanfran-wasm-test --target wasm32-unknown-unknown --release
node -e '
const bytes = require("fs").readFileSync(process.argv[1]);
WebAssembly.instantiate(bytes, {}).then(({ instance }) => {
  const failed = instance.exports.run();
  if (failed !== 0) {
    console.error(`wasm-test: failed checks (bits): ${failed.toString(2)}`);
    process.exit(1);
  }
  console.log("wasm-test: generated code runs on wasm32-unknown-unknown");
});
' target/wasm32-unknown-unknown/release/leanfran_wasm_test.wasm
