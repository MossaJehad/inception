#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
port=$(setting HTTPS_PORT)
suffix=
[[ "$port" == 443 ]] || suffix=":$port"
printf 'WordPress: https://%s%s/\nAdministration: https://%s%s/wp-admin/\nAdministrator: %s\n' "$(setting DOMAIN_NAME)" "$suffix" "$(setting DOMAIN_NAME)" "$suffix" "$(setting WP_ADMIN_USER)"
printf 'Administrator password: %s/secrets/wp_admin_password.txt (mode 600)\n' "$PWD"
printf 'Explicitly display it in your private terminal with: cat secrets/wp_admin_password.txt\n'
printf 'Regular user: %s; password file: secrets/wp_user_password.txt\n' "$(setting WP_USER)"
