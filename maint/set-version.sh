#!/usr/bin/env bash
# Write one version into the backends, each with its own tools: set-version.sh X.Y.Z [backend...]
# Without backends it sets all of them. Release runs one job per backend.
set -euo pipefail
v="$1"
shift
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "set-version.sh: not a version: $v" >&2; exit 2; }
cd "$(dirname "$0")/.."
[[ $# -gt 0 ]] || set -- Rust Python TypeScript Clojure PHP Go C
for backend in "$@"; do
  case "$backend" in
    Rust) (cd langs/Rust && nix shell --inputs-from ../.. nixpkgs#cargo -c ../../maint/Rust/bump-version.sh "$v") ;;
    Python) (cd langs/Python && nix develop ../..#python -c ../../maint/Python/bump-version.sh "$v") ;;
    TypeScript) (cd langs/TypeScript && nix develop ../..#typescript -c ../../maint/TypeScript/bump-version.sh "$v") ;;
    Clojure) (cd langs/Clojure && nix develop ../..#clojure -c clojure -T:build set-version :version "\"$v\"") ;;
    PHP) (cd langs/PHP && nix develop ../..#php -c ../../maint/PHP/bump-version.sh "$v") ;;
    Go) (cd langs/Go && nix develop ../..#go -c ../../maint/Go/bump-version.sh "$v") ;;
    C) maint/C/bump-version.sh "$v" ;;
    *) echo "set-version.sh: unknown backend: $backend" >&2; exit 2 ;;
  esac
done
