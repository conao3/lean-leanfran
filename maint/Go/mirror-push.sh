#!/usr/bin/env bash
set -euo pipefail

exec bash "$(dirname "$0")/../mirror-push.sh" "$@" go.mod
