#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

mkdir -p test-out/schema
lake --dir ../.. build leanfran
nix develop ../..#typescript -c bash -s -- "../../.lake/build/bin/leanfran" <<'TYPESCRIPT'
set -euo pipefail
compiler=$1
for module in Public Json; do
    roots=()
    if [[ $module == Json ]]; then
        roots=(--roots LeanPhpTest.Json.{big,bigEcho,data,shapes,colors,trees})
    fi
    "$compiler" --lang typescript module generate --module-name "LeanPhpTest.$module" \
        --namespace "LeanPhpTest.$module" --search-path .lake/build/lib/lean \
        --runtime-path ../../../TypeScript/src/runtime/index.ts \
        --output-file "test-out/schema/$module.ts" "${roots[@]}" > "test-out/schema/$module.summary.json"
done
node ../../maint/PHP/schema-oracle.mjs > test-out/schema/typescript.json
TYPESCRIPT
