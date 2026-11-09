#!/usr/bin/env bash
# Set the version of the Python package, the Lean CLI and the flake.
# usage: scripts/bump-version.sh <X.Y.Z>
set -euo pipefail
v=$1
cd "$(dirname "$0")/.."
sed -i "s/^version = \".*\"/version = \"$v\"/" pyproject.toml
sed -i "s/^def version : String := \".*\"/def version : String := \"$v\"/" Main.lean
sed -i "s/version = \"[0-9.]*\";/version = \"$v\";/" flake.nix
uv lock -q
grep -q "version = \"$v\"" pyproject.toml
grep -q "def version : String := \"$v\"" Main.lean
