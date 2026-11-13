#!/usr/bin/env bash
# Write one version into the four backends, each in its own dev shell: set-version.sh X.Y.Z
set -euo pipefail
v="$1"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "set-version.sh: not a version: $v" >&2; exit 2; }
cd "$(dirname "$0")/.."
(cd Rust && nix develop ..#rust -c ../maint/Rust/bump-version.sh "$v")
(cd Python && nix develop ..#python -c ../maint/Python/bump-version.sh "$v")
(cd TypeScript && nix develop ..#typescript -c ../maint/TypeScript/bump-version.sh "$v")
(cd Clojure && nix develop ..#clojure -c clojure -T:build set-version :version "\"$v\"")
