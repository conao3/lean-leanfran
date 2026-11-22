#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/PHP"

module=LeanPhpTest.Vectors
lake build leanfran-php "$module"
lake env lean --run LeanPhpTest/ControlCoverage.lean \
    "$module" "$module.run" LeanPhpTest.ControlIr.impossible
