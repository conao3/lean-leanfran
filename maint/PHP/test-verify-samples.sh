#!/usr/bin/env bash
set -euo pipefail

out=$(realpath -m test-out/samples)
compiler=$(realpath ../../.lake/build/bin/leanfran)

for sample in verified-clamp verified-cart; do
    project="$out/$sample"
    rm -rf -- "$project"
    mkdir -p -- "$project"
    cp -R "samples/$sample/"{composer.json,expected.txt,main.php,src,lean} "$project/"
    sed -i 's@"url": "../.."@"url": "../../.."@' "$project/composer.json"
    LEANFRAN_CLI="$compiler" bash samples/run.sh "$project" --verify main.php
    diff -ru "samples/$sample/src" "$project/src"
done
