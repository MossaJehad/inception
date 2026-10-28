#!/bin/sh
set -eu
umask 027
cd /var/www/html
: "${DOMAIN_NAME:?}" "${DB_NAME:?}" "${DB_USER:?}" "${WP_ADMIN_USER:?}" "${WP_USER:?}"
case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in *admin*) echo 'Forbidden administrator username' >&2; exit 1;; esac
install -d -m 750 -o root -g www-data /run/wordpress
install -m 640 -o root -g www-data /run/secrets/db_password /run/wordpress/db_password
if [ ! -e index.php ]; then
    cp -a /usr/src/wordpress/. .
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} +
    find /var/www/html -type f -exec chmod 644 {} +
fi
install -d -m 750 -o root -g www-data .inception
if [ ! -f .inception/salts.php ]; then
    php -r '$s="<?php\n"; foreach (["AUTH_KEY","SECURE_AUTH_KEY","LOGGED_IN_KEY","NONCE_KEY","AUTH_SALT","SECURE_AUTH_SALT","LOGGED_IN_SALT","NONCE_SALT"] as $k) {$s.="define(".var_export($k,true).", ".var_export(bin2hex(random_bytes(64)),true).");\n";} file_put_contents(".inception/salts.php",$s);'
    chown root:www-data .inception/salts.php
    chmod 640 .inception/salts.php
fi
if [ ! -f wp-config.php ]; then
    install -m 640 -o root -g www-data /etc/wordpress/wp-config.php wp-config.php
fi
wp() { /usr/local/bin/wp --allow-root --path=/var/www/html --no-color "$@"; }
ready=0
for attempt in $(seq 1 60); do
    if php -r 'mysqli_report(MYSQLI_REPORT_OFF); $db=@new mysqli("mariadb",getenv("DB_USER"),trim(file_get_contents("/run/wordpress/db_password")),getenv("DB_NAME")); exit($db->connect_errno ? 1 : 0);' 2>/dev/null; then ready=1; break; fi
    sleep 1
done
[ "$ready" -eq 1 ] || { echo 'Database connection timed out; check original credentials and database logs.' >&2; exit 1; }
# Read passwords inside PHP: WP-CLI's prompt facility can echo expanded arguments.
wp eval-file /usr/local/lib/wp-bootstrap.php --skip-wordpress
wp rewrite structure '/%postname%/' --quiet
echo 'WordPress ready; starting PHP-FPM.'
exec "$@"
