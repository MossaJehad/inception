#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
for command in openssl flock awk install; do
    command -v "$command" >/dev/null || fail "Required host command unavailable: $command"
done
umask 077
# Serialize setup without leaving a lock file in the repository.
exec 9<srcs
flock -x 9
if [[ ! -e srcs/.env ]]; then
    cp srcs/.env.example srcs/.env
    printf 'Created srcs/.env from the non-sensitive template.\n'
fi
[[ -f srcs/.env && ! -L srcs/.env ]] || fail 'srcs/.env must be a regular file.'
chmod 600 srcs/.env
data_dir=$(setting DATA_DIR)
[[ "$data_dir" =~ ^/[a-zA-Z0-9_./-]+$ && "$data_dir" != *..* && "$data_dir" == */data* ]] || fail 'DATA_DIR must be an absolute, dedicated data path (no spaces or ..).'
[[ "$data_dir" != / && "$data_dir" != /home && "$data_dir" != /home/mhasoneh ]] || fail 'Unsafe DATA_DIR.'
domain=$(setting DOMAIN_NAME)
[[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] || fail 'Invalid DOMAIN_NAME.'
port=$(setting HTTPS_PORT)
[[ "$port" =~ ^[0-9]{1,5}$ && "$port" -ge 1 && "$port" -le 65535 ]] || fail 'HTTPS_PORT must be in the range 1–65535.'
for key in DB_NAME DB_USER WP_ADMIN_USER WP_USER; do
    value=$(setting "$key")
    [[ "$value" =~ ^[a-zA-Z0-9_]+$ && ${#value} -le 32 ]] || fail "Invalid $key (letters, numbers, underscore; maximum 32)."
done
admin=$(setting WP_ADMIN_USER)
[[ "${admin,,}" != *admin* ]] || fail 'Administrator username must not contain admin.'
[[ "$admin" != "$(setting WP_USER)" ]] || fail 'WordPress users must be distinct.'
[[ "$(setting DB_USER)" != root ]] || fail 'WordPress must use a dedicated database user.'
if [[ -L secrets || ( -e secrets && ! -d secrets ) ]]; then fail 'secrets must be a real directory.'; fi
mkdir -p secrets
chmod 700 secrets
for name in db_root_password db_password wp_admin_password wp_user_password; do
    file="secrets/$name.txt"
    [[ ! -L "$file" ]] || fail "Refusing symlink: $file"
    if [[ ! -e "$file" ]]; then
        # A lost secret must be restored, never silently replaced beside existing data.
        for service in mariadb wordpress; do
            directory="$data_dir/$service"
            if [[ -d "$directory" ]] && { [[ ! -r "$directory" || ! -x "$directory" ]] || [[ -n "$(find "$directory" -mindepth 1 -maxdepth 1 -print -quit)" ]]; }; then
                fail "Missing $file beside existing data. Restore the original secrets from your private backup."
            fi
        done
        temporary=$(mktemp secrets/.generate.XXXXXX)
        openssl rand -hex 32 > "$temporary"
        mv "$temporary" "$file"
        printf 'Generated %s (contents hidden).\n' "$file"
    fi
    [[ -f "$file" ]] || fail "Not a regular secret file: $file"
    [[ "$(cat "$file")" =~ ^[a-f0-9]{64}$ ]] || fail "$file must contain one 64-character lowercase hexadecimal password."
    chmod 600 "$file"
done
for directory in "$data_dir" "$data_dir/mariadb" "$data_dir/wordpress"; do
    [[ ! -L "$directory" ]] || fail "Refusing data directory symlink: $directory"
    if [[ ! -d "$directory" ]]; then
        if ! install -d -m 750 "$directory" 2>/dev/null; then
            printf 'Creating %s requires host privileges; sudo will request authorization.\n' "$directory"
            sudo install -d -m 750 -o "$(id -u)" -g "$(id -g)" "$directory"
        fi
    fi
done
printf 'Setup ready. Persistent storage: %s. Existing configuration and credentials preserved.\n' "$data_dir"
