#!/bin/sh
set -eu
umask 077
: "${DB_NAME:?DB_NAME required}" "${DB_USER:?DB_USER required}"
case "$DB_NAME:$DB_USER" in *[!a-zA-Z0-9_:]*) echo 'Invalid database identifiers' >&2; exit 1;; esac
root_password=$(cat /run/secrets/db_root_password)
db_password=$(cat /run/secrets/db_password)
for password in "$root_password" "$db_password"; do
    [ "${#password}" -eq 64 ] && ! printf '%s' "$password" | grep -q '[^a-f0-9]' || { echo 'Invalid secret format' >&2; exit 1; }
done
install -d -m 755 -o mysql -g mysql /run/mysqld
cat > /run/mysqld/root.cnf <<EOF
[client]
user=root
password=$root_password
socket=/run/mysqld/mysqld.sock
EOF
chmod 600 /run/mysqld/root.cnf
if [ ! -f /var/lib/mysql/.inception-initialized ]; then
    if [ ! -d /var/lib/mysql/mysql ]; then
        chown mysql:mysql /var/lib/mysql
        chmod 700 /var/lib/mysql
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal --skip-test-db >/dev/null
    fi
    mariadbd --user=mysql --skip-networking --console &
    temporary_pid=$!
    cleanup() { kill -TERM "$temporary_pid" 2>/dev/null || :; wait "$temporary_pid" 2>/dev/null || :; }
    trap cleanup EXIT
    trap 'exit 143' TERM INT
    ready=0
    for attempt in $(seq 1 60); do
        if mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent >/dev/null 2>&1; then ready=1; break; fi
        kill -0 "$temporary_pid" 2>/dev/null || { echo 'Temporary MariaDB exited' >&2; exit 1; }
        sleep 1
    done
    [ "$ready" -eq 1 ] || { echo 'MariaDB initialization timed out' >&2; exit 1; }
    # Support recovery after interruption between securing root and writing the marker.
    if mariadb --defaults-extra-file=/run/mysqld/root.cnf -e 'SELECT 1' >/dev/null 2>&1; then
        set -- mariadb --defaults-extra-file=/run/mysqld/root.cnf
    else
        set -- mariadb --user=root --socket=/run/mysqld/mysqld.sock
    fi
    "$@" <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
DELETE FROM mysql.global_priv WHERE User='' OR (User='root' AND Host <> 'localhost');
DELETE FROM mysql.proxies_priv;
DROP DATABASE IF EXISTS test;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_password';
FLUSH PRIVILEGES;
EOF
    mariadb --defaults-extra-file=/run/mysqld/root.cnf -e 'SELECT 1' >/dev/null
    touch /var/lib/mysql/.inception-initialized
    chown mysql:mysql /var/lib/mysql/.inception-initialized
    cleanup
    trap - EXIT TERM INT
    set -- mariadbd --user=mysql --console
    echo 'MariaDB initialization complete.'
fi
unset root_password db_password password
exec "$@"
