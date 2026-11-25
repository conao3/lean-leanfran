#!/usr/bin/env bash
# Print the version that follows the highest version of the backends and the vX.Y.Z tags: next-version.sh patch|minor|major
set -euo pipefail
cd "$(dirname "$0")/.."
tag=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
if [[ -n $tag ]] && ! git merge-base --is-ancestor "$tag^{commit}" HEAD; then
  echo "next-version.sh: $tag is not in $(git rev-parse HEAD). Merge $tag into the release branch if it lacks $tag, then start a new Release run from the latest release branch." >&2
  exit 1
fi
current=$(
  {
    echo "${tag#v}"
    sed -n '/^\[workspace.package\]/,/^\[/s/^version = "\(.*\)"/\1/p' langs/Rust/Cargo.toml
    sed -n 's/^version = "\(.*\)"/\1/p' langs/Python/pyproject.toml
    sed -n 's/^  "version": "\(.*\)",$/\1/p' langs/TypeScript/package.json
    sed -n 's/.*:version "\([0-9.]*\)".*/\1/p' langs/Clojure/deps.edn
    sed -n 's/^def version : String := "\([0-9.]*\)"$/\1/p' langs/PHP/Main.lean
    sed -n 's/^def version : String := "\([0-9.]*\)"$/\1/p' langs/Go/Main.lean
    sed -n 's/^version = "\([0-9.]*\)"$/\1/p' langs/C/lakefile.toml
  } | sort -V | tail -n 1
)
IFS='.' read -r major minor patch <<< "$current"
case "$1" in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
  *) echo "next-version.sh: unknown part: $1" >&2; exit 2 ;;
esac
