#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

module=LeanGoTest.Vectors
lake build leanfran-go "$module"
lake env lean --run LeanGoTest/ControlCoverage.lean \
    "$module" "$module.run" LeanGoTest.ControlIr.impossible
