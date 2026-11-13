#!/usr/bin/env bash
# Print the version that follows the highest version of the backends: next-version.sh patch|minor|major
set -euo pipefail
cd "$(dirname "$0")/.."
current=$(
  {
    sed -n '/^\[workspace.package\]/,/^\[/s/^version = "\(.*\)"/\1/p' Rust/Cargo.toml
    sed -n 's/^version = "\(.*\)"/\1/p' Python/pyproject.toml
    sed -n 's/^  "version": "\(.*\)",$/\1/p' TypeScript/package.json
    sed -n 's/.*:version "\([0-9.]*\)".*/\1/p' Clojure/deps.edn
  } | sort -V | tail -n 1
)
IFS='.' read -r major minor patch <<< "$current"
case "$1" in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
  *) echo "next-version.sh: unknown part: $1" >&2; exit 2 ;;
esac
