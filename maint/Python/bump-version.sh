#!/usr/bin/env bash
# Set the version of the Python package and the Lean CLI.
# usage: ../../maint/Python/bump-version.sh <X.Y.Z>
set -euo pipefail
v=$1
cd "$(dirname "$0")/../../langs/Python"
sed -i "s/^version = \".*\"/version = \"$v\"/" pyproject.toml
sed -i "s/^def version : String := \".*\"/def version : String := \"$v\"/" Main.lean
uv lock -q
grep -q "version = \"$v\"" pyproject.toml
grep -q "def version : String := \"$v\"" Main.lean
