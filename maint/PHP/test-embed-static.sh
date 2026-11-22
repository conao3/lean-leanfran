#!/usr/bin/env bash
set -euo pipefail

config=$(realpath phpstan-types.neon)

analyze() (
    cd "$1"
    shift
    local -a sources=("$@")
    while IFS= read -r -d '' file; do
        sources+=("$file")
    done < <(find src -type d -name Internal -prune -o -type f -name '*.php' -print0)
    phpstan analyse --configuration="$config" --level=max --no-progress --memory-limit=512M --autoload-file=vendor/autoload.php "${sources[@]}"
)

analyze test-out/embed/project run.php validate.php
analyze test-out/samples/embed-range main.php
analyze test-out/samples/embed-orders main.php
