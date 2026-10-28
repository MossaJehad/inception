#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ -f srcs/.env ]] || fail 'No srcs/.env. Nothing will be erased; restore the original configuration first.'
data_dir=$(setting DATA_DIR)
prefix=$(setting VOLUME_PREFIX)
project=$(setting COMPOSE_PROJECT_NAME)
[[ "$data_dir" =~ ^/[a-zA-Z0-9_./-]+$ && "$data_dir" != *..* && "$data_dir" == */data* ]] || fail 'Unsafe DATA_DIR.'
# Verify both targets before mutating anything. Never prune unrelated Docker resources.
for service in mariadb wordpress; do
    volume="${prefix}${service}_data"
    docker volume inspect "$volume" >/dev/null || fail "Missing $volume; restore its Compose definition with make before cleanup."
    actual=$(docker volume inspect --format '{{index .Options "device"}}' "$volume")
    owner=$(docker volume inspect --format '{{index .Labels "com.docker.compose.project"}}' "$volume")
    [[ "$actual" == "$data_dir/$service" && "$owner" == "$project" ]] || fail "Volume $volume does not belong to this configured stack."
done
compose down --remove-orphans
restore_uid=$(id -u)
restore_gid=$(id -g)
if docker info --format '{{json .SecurityOptions}}' | grep -q rootless; then
    restore_uid=0
    restore_gid=0
fi
for service in mariadb wordpress; do
    docker run --rm --pull never --network none --user 0 \
        --mount "type=volume,source=${prefix}${service}_data,target=/erase" \
        --entrypoint /bin/sh "${service}:inception" -c \
        'find /erase -mindepth 1 -delete && chown "$1:$2" /erase && chmod 750 /erase' sh "$restore_uid" "$restore_gid"
done
compose down --volumes --remove-orphans
rm -f srcs/.env secrets/db_password.txt secrets/db_root_password.txt secrets/wp_admin_password.txt secrets/wp_user_password.txt
rmdir secrets 2>/dev/null || :
printf 'Erased this stack’s persistent contents, volume definitions, .env, and four secret files. Images retained.\n'
