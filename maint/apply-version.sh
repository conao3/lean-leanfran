#!/usr/bin/env bash
# Apply and verify the version patches from the Release jobs: apply-version.sh X.Y.Z
set -euo pipefail
if [[ $# != 1 || ! ${1-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'usage: maint/apply-version.sh X.Y.Z' >&2
  exit 2
fi
version=$1
cd "$(dirname "$0")/.."
shopt -s nullglob
patches=(version-*.patch)
[[ ${#patches[@]} -gt 0 ]] || { echo "apply-version.sh: no version-*.patch" >&2; exit 1; }
applied=0
for patch in "${patches[@]}"; do
  if [[ -s "$patch" ]]; then
    git apply "$patch"
    applied=$((applied + 1))
  fi
  rm "$patch"
done
[[ $applied -gt 0 ]] || { echo "apply-version.sh: every patch is empty" >&2; exit 1; }

check_version() {
  local actual versions
  versions=$(sed -En "$2" "$1")
  while IFS= read -r actual; do
    if [[ $actual != "$version" ]]; then
      printf 'apply-version.sh: %s: expected version %s, found %s\n' \
        "$1" "$version" "${actual:-<missing>}" >&2
      return 1
    fi
  done <<< "$versions"
}

for cli in Rust/LeanRust Python/LeanPython TypeScript/LeanTs Clojure/LeanClj PHP/LeanPhp Go/LeanGo; do
  check_version "langs/$cli/Cli.lean" 's/^def version : String := "([^"]*)"$/\1/p'
done

check_version langs/Rust/Cargo.toml '/^\[workspace\.package\]/,/^\[/s/^version = "([^"]*)"$/\1/p'
for manifest in langs/Rust/crates/*/Cargo.toml; do
  if grep -Eq '^leanfran-[a-z]+ = \{ path = "[^"]*", version = "' "$manifest"; then
    check_version "$manifest" 's/^leanfran-[a-z]+ = \{ path = "[^"]*", version = "([^"]*)".*/\1/p'
  fi
done
for manifest in langs/Rust/{crates,tests}/*/Cargo.toml; do
  if grep -Fxq 'version.workspace = true' "$manifest"; then
    package=$(sed -En '/^\[package\]/,/^\[/s/^name = "([^"]*)"$/\1/p' "$manifest")
    check_version langs/Rust/Cargo.lock "/^name = \"$package\"$/,/^\[\[package\]\]/s/^version = \"([^\"]*)\"$/\\1/p"
  fi
done
check_version langs/Rust/README.md 's/^leanfran = ("|\{ version = ")([^"]*)".*/\2/p'
check_version langs/Rust/README.md 's/^leanfran-build = "([^"]*)"$/\1/p'
check_version docs/rust-guide.md 's/^leanfran = \{ version = "([^"]*)".*/\1/p'

check_version langs/Python/pyproject.toml 's/^version = "([^"]*)"$/\1/p'
check_version langs/Python/uv.lock '/^name = "leanfran"$/,/^\[\[package\]\]/s/^version = "([^"]*)"$/\1/p'
check_version langs/TypeScript/package.json 's/^  "version": "([^"]*)",$/\1/p'
check_version langs/Clojure/deps.edn 's/^[[:space:]]*:version "([^"]*)"$/\1/p'
check_version langs/Clojure/src/leanfran/core.clj '/^\(def generator-version$/,/^$/s/^  "([^"]*)"\)$/\1/p'
check_version langs/Clojure/README.md 's/.*\{:mvn\/version "([^"]*)"\}.*/\1/p'
check_version langs/Go/leanfran.go 's/^const Version = "([^"]*)"$/\1/p'
git ls-files -z -- 'langs/Go/samples/*/go.mod' 'langs/Go/testdata/*/go.mod' |
  while IFS= read -r -d '' manifest; do
    check_version "$manifest" 's/^(require[[:space:]]+|[[:space:]]+)github\.com\/conao3\/leanfran-go v([^[:space:]]+).*$/\2/p'
  done
check_version langs/C/lakefile.toml 's/^version = "([^"]*)"$/\1/p'
check_version langs/C/support/leanfran.h 's/^#define LEANFRAN_VERSION "([^"]*)"$/\1/p'
