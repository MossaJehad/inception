#!/bin/sh
set -eu
test -f /var/lib/mysql/.inception-initialized
exec mariadb --defaults-extra-file=/run/mysqld/root.cnf --connect-timeout=2 --batch --skip-column-names -e 'SELECT 1'
