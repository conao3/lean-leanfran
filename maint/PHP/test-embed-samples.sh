#!/usr/bin/env bash
set -euo pipefail

out=$(realpath -m test-out/samples)
compiler=$(realpath ../../.lake/build/bin/leanfran)
export COMPOSER_DISABLE_NETWORK=1

for sample in embed-range embed-orders; do
    (
        cd "samples/$sample"
        composer update --no-interaction --no-progress --no-audit
        "$compiler" --lang php status
        test -z "$(git status --porcelain --untracked-files=all -- .)"
    )
    project="$out/$sample"
    rm -rf -- "$project"
    mkdir -p -- "$project"
    cp -R "samples/$sample/"{composer.json,expected.txt,main.php,src,leanfran.manifest.json} "$project/"
    sed -i 's@"url": "../.."@"url": "../../.."@' "$project/composer.json"
    bash samples/run.sh "$project" main.php
    (
        cd "$project"
        "$compiler" --lang php sync
        "$compiler" --lang php status
        diff -ru "$OLDPWD/samples/$sample/src" src
        diff -u "$OLDPWD/samples/$sample/leanfran.manifest.json" leanfran.manifest.json
    )
done
