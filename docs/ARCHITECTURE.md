# Architecture

```text
Browser -- HTTPS 443 --> nginx -- FastCGI 9000 --> wordpress -- SQL 3306 --> mariadb
                          |
                          +-- /portfolio/ -- HTTP 8080 --> static_site

wordpress_data -> wordpress:/var/www/html and nginx:/var/www/html (read only)
mariadb_data   -> mariadb:/var/lib/mysql
```

All four services explicitly share the `inception` user-defined bridge network.
No database, FPM, or bonus host port is published. Each image is built from its
own Dockerfile using `debian:12.15-slim`, not a prebuilt application image.

The two local-driver named volumes map storage beneath `/home/mhasoneh/data`.
The driver binds host directories internally; service mount definitions remain
Docker named volumes. No third persistent storage is needed. The portfolio is
baked into its image; certificates live in the NGINX container layer.

Compose grants MariaDB its root/database secret files and WordPress its database
and account secret files. NGINX and the portfolio receive no passwords. Protected
runtime copies let PHP read its database secret without weakening host-file modes.
Initialization is idempotent and dependency health gates initial startup.

Mandatory service entrypoints replace themselves with the foreground daemon.
Static HTTP runs under Docker tiny init to forward signals/reap children.
`unless-stopped` applies to each service. Docker DNS and NGINX's runtime resolver
support backend recreation. The only bonus is the static portfolio.

See [DEV_DOC.md](../DEV_DOC.md) for implementation and operations, and
[VALIDATION.md](VALIDATION.md) for verification evidence and VM limitations.
