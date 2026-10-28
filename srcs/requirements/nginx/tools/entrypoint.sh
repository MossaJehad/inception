#!/bin/sh
set -eu
umask 077
: "${DOMAIN_NAME:?DOMAIN_NAME required}"
case "$DOMAIN_NAME" in *[!a-zA-Z0-9.-]*|'') echo 'Invalid domain' >&2; exit 1;; esac
install -d -m 700 /etc/nginx/tls
if [ ! -s /etc/nginx/tls/server.key ] || [ ! -s /etc/nginx/tls/server.crt ] || \
    ! openssl x509 -checkend 86400 -noout -in /etc/nginx/tls/server.crt >/dev/null 2>&1; then
    openssl req -x509 -nodes -newkey rsa:3072 -sha256 -days 365 \
        -keyout /etc/nginx/tls/server.key -out /etc/nginx/tls/server.crt \
        -subj "/CN=$DOMAIN_NAME" -addext "subjectAltName=DNS:$DOMAIN_NAME" \
        -addext 'basicConstraints=critical,CA:FALSE' \
        -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
        -addext 'extendedKeyUsage=serverAuth' 2>/dev/null
fi
HTTPS_PORT=${HTTPS_PORT:-443}
case "$HTTPS_PORT" in *[!0-9]*|'') echo 'Invalid HTTPS port' >&2; exit 1;; esac
PUBLIC_HOST=$DOMAIN_NAME
[ "$HTTPS_PORT" = 443 ] || PUBLIC_HOST="$DOMAIN_NAME:$HTTPS_PORT"
export PUBLIC_HOST HTTPS_PORT
envsubst '${DOMAIN_NAME} ${PUBLIC_HOST} ${HTTPS_PORT}' < /etc/nginx/templates/site.conf.template > /etc/nginx/conf.d/site.conf
nginx -t
exec "$@"
