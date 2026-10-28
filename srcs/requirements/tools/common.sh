#!/usr/bin/env bash
# Host-side helpers; never evaluate .env as shell code.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
setting() {
    local key=$1 value
    value=$(awk -v key="$key" 'index($0, key "=") == 1 {sub(/^[^=]*=/, ""); print; exit}' srcs/.env)
    printf '%s' "${!key-$value}"
}
compose() { docker compose --env-file srcs/.env -f srcs/docker-compose.yml "$@"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
