#!/usr/bin/env bash
set -euo pipefail

out=$(realpath -m test-out/samples)
compiler=$(realpath ../../.lake/build/bin/leanfran)

for sample in verified-clamp verified-cart; do
    (
        cd "samples/$sample"
        composer update --no-interaction --no-progress --no-audit
        "$compiler" --lang php status --require proved
        test -z "$(git status --porcelain --untracked-files=all -- .)"
    )
    project="$out/$sample"
    rm -rf -- "$project"
    mkdir -p -- "$project"
    cp -R "samples/$sample/"{composer.json,expected.txt,main.php,src,lean,leanfran.manifest.json,leanfran.lock} "$project/"
    sed -i 's@"url": "../.."@"url": "../../.."@' "$project/composer.json"
    LEANFRAN_CLI="$compiler" bash samples/run.sh "$project" --verify main.php
    diff -ru "samples/$sample/src" "$project/src"
    diff -u "samples/$sample/leanfran.manifest.json" "$project/leanfran.manifest.json"
    diff -u "samples/$sample/leanfran.lock" "$project/leanfran.lock"
done
