#!/usr/bin/env bash
set -euo pipefail

out=$(realpath -m test-out/samples)
compiler=$(realpath .lake/build/bin/leanfran-php)
export COMPOSER_DISABLE_NETWORK=1

for sample in embed-range embed-orders; do
    project="$out/$sample"
    rm -rf -- "$project"
    mkdir -p -- "$project"
    cp -R "samples/$sample/"{composer.json,expected.txt,main.php,src} "$project/"
    sed -i 's@"url": "../.."@"url": "../../.."@' "$project/composer.json"
    bash samples/run.sh "$project" main.php
    (
        cd "$project"
        vendor/bin/leanfran sync --leanfran-php "$compiler"
        vendor/bin/leanfran status
        diff -ru "$OLDPWD/samples/$sample/src" src
    )
done
