# Developer documentation

## Prerequisites and VM installation

Use a standard Linux VM for evaluation, a local Linux filesystem for data, Git,
GNU Make, Bash, OpenSSL, coreutils, util-linux (`flock`), Docker Engine, and Docker
Compose v2.20+. The test runner additionally uses Python 3, curl, and OpenSSL's
client. No Docker Desktop, WSL paths, external Compose overrides, or Python
packages are required. The daemon must be local to the checkout/data paths.

For a fresh **Debian 12/13 VM**, install Docker from its official apt repository.
Use the [current Docker Debian instructions](https://docs.docker.com/engine/install/debian/)
if the host distribution changes. Ubuntu requires its own official Ubuntu
repository; do not use these Debian commands on Ubuntu. Resolve conflicting old
Docker packages as described by Docker before installation.

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl git make openssl util-linux python3
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF_DOCKER
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF_DOCKER
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$(id -un)"
```

Log out and log back in, then run `docker info` and `docker compose version`.
Docker group membership grants powerful host access; restrict it to trusted users.
Do not run ordinary project Make targets under sudo, which would create
root-owned local credentials. Setup elevates only host-directory creation when
necessary. The project does not install system packages or edit hosts files.

On the browser machine, use `sudoedit /etc/hosts` and map the VM's reachable IP
to `mhasoneh.42.fr`. On the VM itself, `127.0.0.1 mhasoneh.42.fr` permits local
checks. For NAT networking, configure host forwarding for HTTPS; for bridged/host
only networking, use the VM IP. Permit HTTPS through the VM firewall as needed.

## Fresh clone and automatic setup

```sh
git clone https://github.com/MossaJehad/inception.git
cd inception
make
make ps
make credentials
curl -k --resolve mhasoneh.42.fr:443:127.0.0.1 https://mhasoneh.42.fr/
```

These commands assume the completed source has been pushed by its owner. Nothing
in the project pushes or commits automatically. `make` uses
`docker compose --env-file srcs/.env -f srcs/docker-compose.yml` from the root.
All service configuration lives under `srcs/`.

`setup.sh` locks the `srcs` directory using `flock`, sets umask 077, copies the
example only if needed, validates settings, and generates only missing secrets.
It never shell-sources `.env`. Use the documented plain `KEY=value` format, with
no shell expansion, quoting, or inline comments. Compose handles the non-sensitive
values; host helpers read only the documented keys. Preserve existing identities
and storage paths after first initialization unless performing a planned migration.

| Variable | Default / meaning |
| --- | --- |
| `COMPOSE_PROJECT_NAME` | `inception`; scopes containers/network |
| `DOMAIN_NAME` | `mhasoneh.42.fr` |
| `DATA_DIR` | `/home/mhasoneh/data`; dedicated absolute local path |
| `HTTPS_PORT` | `443`; optional local rootless override `8443` |
| `VOLUME_PREFIX` | Empty; test runner uses a unique prefix |
| `DB_NAME`, `DB_USER` | `wordpress`, `wpuser` |
| `WP_TITLE` | `Inception \| mhasoneh` |
| `WP_ADMIN_USER`, `WP_USER` | `mhasoneh`, `editor42` |
| `WP_ADMIN_EMAIL`, `WP_USER_EMAIL` | Explicit non-deliverable `example.invalid` placeholders |

`srcs/.env` and `secrets/` are ignored by Git. The example is committed and has no
passwords. Generated passwords are 64 lowercase hex characters from OpenSSL's
cryptographic RNG. The four files are `db_root_password.txt`, `db_password.txt`,
`wp_admin_password.txt`, and `wp_user_password.txt`. Setup enforces mode 700 on
the directory and 600 on files; it validates existing secrets rather than
silently overwriting them. Missing credentials beside populated/unreadable data
cause an explicit failure. Restore the originals from private backup.

Data directories are created with mode 750 and the real invoking user's UID/GID.
Setup invokes `sudo install` only when ordinary creation fails and explains why.
MariaDB takes ownership of its data and uses mode 700. WordPress initializes
application files with service ownership, then protects configuration and salts.
Existing data directory permissions are not recursively reset by host setup.

## Images and initialization

Every service builds its own Dockerfile from `debian:12.15-slim`, checked as the
penultimate stable Debian series on 2026-10-28. No `latest` base or prebuilt
application image is used. `image: <service>:inception` keeps the repository name
identical to its service; `pull_policy: never` prevents pulling application images.
Builds obtain updated Debian packages; they are not a fully frozen package
snapshot. WordPress 7.1.3 and WP-CLI 2.12.0 downloads have pinned SHA-256 checksums.
Change version and checksum together when deliberately upgrading.

Each `.dockerignore` starts by excluding everything, then permits only the
Dockerfile and required source directories. Secrets are outside service contexts;
no secret is a Docker ARG, ENV, COPY, or build input.

| Container | Initialization | Foreground process |
| --- | --- | --- |
| MariaDB | Initialize absent system tables; start a temporary socket-only daemon; create database/user; remove anonymous/remote-root accounts; secure root; mark completion | `mariadbd --user=mysql --console` |
| WordPress | Copy bundled source only into a new site; create persistent random salts and protected config; bounded DB connection check; run WordPress's own PHP installer and create editor only if missing | `php-fpm8.2 --nodaemonize` |
| NGINX | Generate SAN self-signed TLS certificate/key; substitute the domain and canonical public host/port into its template; validate configuration | `nginx -g 'daemon off;'` |
| Static site | Site and MIME configuration baked into its image; no runtime initialization | `busybox httpd -f ...` as `www-data`, under Docker tiny init |

MariaDB uses a local-only root password, not a passwordless socket fallback after
bootstrap. `wpuser` receives database-scoped privileges without global privileges
or grant option. No SQL user creation runs on ordinary restarts. A marker is
written only after successful bootstrap. Interrupted initialization before the
marker can authenticate with the original root secret and retry safely.

WordPress bootstrap is a PHP file invoked by WP-CLI. It calls `wp_install` and
`wp_insert_user`, reading password files inside PHP. WP-CLI prompt handling was
found to echo expanded passwords during testing, so no password prompt or password
argument is used. Initialization is idempotent and does not reset existing users.
Database password access uses `/run/wordpress/db_password` (root:www-data, 640),
not a literal in shared `wp-config.php`. Config and salts are root:www-data 640;
NGINX denies HTTP access. PHP-FPM retains only non-sensitive service environment
configuration via `clear_env = no`.

Entrypoint scripts finish with `exec`, replacing the shell with the real daemon
as PID 1. MariaDB handles SIGTERM; NGINX and PHP-FPM receive SIGQUIT for graceful
shutdown. The temporary initialization daemon has signal/exit cleanup traps.
The static service uses Compose `init: true`: Docker’s tiny init forwards signals
to the foreground HTTP child and reaps children. This avoids BusyBox ignoring a
default termination signal when it is PID 1. No idle keepalive loops or shell
daemons are used. Readiness loops are bounded.

## Compose, networking, and health

Exactly four services join the user-defined `inception` bridge (normally named
`inception_inception`). MariaDB uses port 3306, FPM 9000, and portfolio HTTP 8080
internally. `EXPOSE` documents internal ports; it does not publish them. The only
host mapping is NGINX HTTPS 443. No host network, links, or privileged mode exists.
The static container drops all capabilities and uses a read-only root filesystem.
All containers enable `no-new-privileges`.

Docker DNS resolves `mariadb`, `wordpress`, and `static_site`. NGINX uses Docker's
embedded resolver with variable upstreams so recreated backend addresses do not
require a manually restarted proxy. FastCGI supplies the absolute script path and
HTTPS status to FPM. Missing scripts return 404; uploads cannot execute PHP.
Hidden files, config, SQL dumps, backups, readme, and XML-RPC are denied.

`depends_on: condition: service_healthy` gates initial startup. Database health
checks authenticated SQL; FPM uses a FastCGI ping; NGINX uses HTTPS `/healthz`;
static HTTP uses BusyBox wget. `up --wait` detects startup failures. Each container
has `restart: unless-stopped`; Docker restarts crashed processes but does not
restart a process merely because its healthcheck fails. Runtime WordPress HTTP
checks complement the narrower FPM healthcheck.

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config --quiet
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress getent hosts mariadb
docker network inspect inception_inception
docker volume inspect mariadb_data wordpress_data
```

## Storage, backups, and recovery

Exactly two top-level named volumes use the Docker local driver:

| Name | Host device | Mounts |
| --- | --- | --- |
| `mariadb_data` | `/home/mhasoneh/data/mariadb` | MariaDB `/var/lib/mysql` |
| `wordpress_data` | `/home/mhasoneh/data/wordpress` | WordPress `/var/www/html`; NGINX same path read only |

Driver options `type: none`, `o: bind`, `device: ...` select host storage while
service mounts remain named volumes (`docker inspect` reports `Type: volume`).
Compose file secrets are separate read-only file mounts, not extra data volumes.
No data is committed. Changing DATA_DIR does not change an existing volume's
options automatically. Back up and migrate deliberately; never attach one live
MariaDB directory to multiple servers.

For a consistent offline backup, stop the stack and archive both volumes through
the matching images. Keep backup files private:

```sh
make stop
umask 077
mkdir -p backups
chmod 700 backups
docker compose --env-file srcs/.env -f srcs/docker-compose.yml run --rm --no-deps -T --entrypoint tar mariadb -C /var/lib/mysql -czf - . > backups/mariadb.tgz
docker compose --env-file srcs/.env -f srcs/docker-compose.yml run --rm --no-deps -T --entrypoint tar wordpress -C /var/www/html -czf - . > backups/wordpress.tgz
cp -a secrets backups/
cp -p srcs/.env backups/environment
make start
```

Protect these backups as credentials: WordPress salts and the database's account
hashes are sensitive. Copy backups outside this machine. Restore into an **empty,
stopped** installation using the original secrets/config and compatible database
image version. Create named volumes with Compose, then extract each archive at its
matching container mount using a one-off `--entrypoint tar` container; preserve
numeric ownership. Do not extract over a running or populated database. Backup
commands are documented operational procedures; cross-VM restore validation is
pending, as recorded in the validation report.

`down`, `clean`, `stop`, and `re` preserve data. `fclean` first validates both volume
owners and host devices, stops this stack, erases only those volume contents,
restores empty directory ownership, removes the volume definitions, and removes
local generated config/secrets. It requires `CONFIRM=DELETE`, retains images, and
never invokes system-wide prune. A missing or foreign volume causes refusal.

## Secrets and password rotation

Host secrets are mode 600 and Compose grants them only to needed services.
Standalone Compose uses local file mounts; it does not encrypt files at rest.
Root/master processes read them. NGINX and the static site receive no passwords.
Runtime root client config is root-only; persistent WordPress config has no DB
password. Never enable shell tracing or put passwords in issue reports/logs.

For an intentional WordPress administrator rotation, read the new password through
stdin and then replace its secret file, keeping file permissions. This operation
changes a credential and should be done deliberately by the operator:

```sh
umask 077
openssl rand -hex 32 > secrets/.wp_admin_password.new
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T wordpress wp --allow-root eval '$u=get_user_by("login",getenv("WP_ADMIN_USER")); wp_set_password(trim(stream_get_contents(STDIN)), $u->ID);' < secrets/.wp_admin_password.new
mv secrets/.wp_admin_password.new secrets/wp_admin_password.txt
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --force-recreate --wait wordpress nginx
```

For the editor, substitute `WP_USER`, `wp_user_password.txt`, and a distinct temp
file. For database password/root rotation, coordinate the MariaDB ALTER USER
operation over its authenticated local socket with the corresponding file, then
recreate consumers so file mounts and protected runtime copies refresh. Replacing
files alone never changes database accounts. Maintain a private backup and do not
pass passwords as command arguments.

## TLS and local versus VM operation

NGINX listens only on 443 inside the container and allows TLSv1.2/TLSv1.3 only.
The development certificate uses RSA-3072/SHA-256, a domain SAN, server-auth usage,
and 365-day validity; the private key is mode 600. It is self-signed, not publicly
trusted. A certificate lives in the NGINX container's writable layer, survives
restart, and regenerates on recreation; no third persistent volume is introduced.
For certificate inspection:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T nginx cat /etc/nginx/tls/server.crt > /tmp/inception-public.crt
openssl x509 -in /tmp/inception-public.crt -noout -subject -dates -ext subjectAltName
openssl s_client -connect 127.0.0.1:443 -servername mhasoneh.42.fr -tls1_2
openssl s_client -connect 127.0.0.1:443 -servername mhasoneh.42.fr -tls1_3
```

The local rootless host restricts ports below 1024, so its ignored `.env` uses
`HTTPS_PORT=8443`. All defaults in Git remain 443. The VM should use standard
Docker Engine with the fresh example, default storage path, and default port.
A Git clone generates independent random credentials and empty data; copying
source alone does not migrate the local website. To migrate content, use private
backups with original secrets and update URLs as needed. No VM execution occurred
in this workspace; clone/boot/reboot/hosts checks inside the VM remain required.

## Commands, tests, and debugging

| Make target | Behavior |
| --- | --- |
| default / `up` | setup, validate, build, start, wait |
| `setup`, `config`, `build` | prepare; validate Compose; build all images |
| `down` / `clean` | remove stack containers/network, keep data |
| `stop`, `start`, `restart` | process lifecycle; start/restart wait for health |
| `logs`, `ps`, `credentials` | follow logs; status; safe credential locations |
| `re` | down, build without cache, start; preserve volumes/secrets |
| `fclean CONFIRM=DELETE` | explicit destructive stack-only reset |
| `test` | isolated fresh-source acceptance suite |

`verify.py` exports tracked and nonignored candidate source into a private checkout
without `.env` or secrets. It uses local `/tmp`, a unique Compose project, volume
prefix, data path, and available high host port. It invokes the real `make`, logs
in over HTTP, creates a post/media, exercises lifecycle/crash recovery, verifies
network/TLS/security, scans exported image layers for generated secrets, and
cleans only its disposable stack. Shared image tags/build cache can be rebuilt by
the test; normal containers/data/secrets are not modified. Do not build differing
revisions concurrently against these same image tags.

A private fixture is retained on failure with `commands.log`; inspect it locally
and clean its resources using its reported project/prefix/data environment, not
the normal stack. The runner writes `.cache/verification.json`. Logs may contain
WordPress nonces/session information and must stay private even though generated
passwords are checked for leakage. `make test` requires no external Python packages.

Inspect relevant logs after failures; rebuild only affected images when changing
source. Container scripts support `sh -n`; host scripts support `bash -n`.
Use a local filesystem for Docker data: network-home/NFS ownership can break
container UID mappings. Do not mask daemon failures with keepalive loops.

## Defense explanations and demonstration

| Concept | Explain using this implementation |
| --- | --- |
| Image vs container | An image is a read-only layered build artifact; a container is a running instance with writable state and mounts. |
| Dockerfile vs Compose | Dockerfile builds one service image; Compose connects services, runtime settings, secrets, volumes, and networking. |
| PID 1 | The container's initial process receives stop signals and manages its children; `exec` gives that role to the daemon. |
| ENTRYPOINT vs CMD | ENTRYPOINT performs initialization; CMD provides its default daemon arguments. Static HTTP needs only CMD. |
| Foreground process | Daemon stays attached to container lifetime; exiting PID 1 exits the container. |
| Named volume | Independently named Docker storage; local driver options place it at the required host directory. |
| Docker networking | A bridge isolates the stack and resolves service names; only published 443 reaches the host. |
| MariaDB initialization | System tables, socket-only temporary server, least-scope user, secured local root, completion marker. |
| PHP-FPM | A FastCGI pool of PHP workers; it runs PHP and is not an HTTP server. |
| NGINX FastCGI | Static assets stay in NGINX; PHP requests carry script filename and HTTPS metadata to FPM. |
| TLS | Encrypts/authenticates the HTTPS connection; self-signing requires explicit client trust. |
| Environment vs secrets | Names/URLs in `.env`; confidential values in restricted runtime files. |
| Restart policy | Recovers exited daemons unless explicitly stopped; health alone is not an automatic restart. |
| Healthcheck | Tests a useful readiness signal; dependency health gates initial startup. |
| Persistence | Posts are in MariaDB, uploads in the WordPress volume; rebuilding images cannot erase them. |

Demonstrate `make`, `make ps`, HTTPS/TLS protocols, both users, and the portfolio.
Show Compose port/network/volume inspection and PID 1. Create a post and image,
run `make down` and `make`, and show both still exist. Explain every script before
running the isolated `make test`. Never use destructive cleanup to demonstrate
persistence on the evaluator's valuable data. Practice a small source/config
change and targeted rebuild; the supplied subject allows a brief modification.
