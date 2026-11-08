#!/usr/bin/env bash
# Set the version of the crates, the lean-rust CLI and the nix packages: bump-version.sh <new version>
set -euo pipefail
new="$1"
old=$(sed -n '/^\[workspace.package\]/,/^\[/s/^version = "\(.*\)"/\1/p' Cargo.toml)
sed -i "/^\[workspace.package\]/,/^\[/s/^version = \"$old\"/version = \"$new\"/" Cargo.toml
sed -i "s/\(lean-rust-[a-z]* = { path = \"[^\"]*\", version = \"\)$old\"/\1$new\"/" crates/*/Cargo.toml
sed -i "s/^def version : String := \"$old\"/def version : String := \"$new\"/" Main.lean
sed -i "s/version = \"$old\";/version = \"$new\";/; s/name = \"lean-rs-$old\";/name = \"lean-rs-$new\";/" flake.nix
cargo update --workspace --offline >/dev/null 2>&1 || cargo update --workspace >/dev/null
echo "$old -> $new"
