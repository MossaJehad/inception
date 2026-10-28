# User documentation

## Available services

| Service | Address or purpose |
| --- | --- |
| WordPress | `https://mhasoneh.42.fr/` |
| WordPress administration | `https://mhasoneh.42.fr/wp-admin/` |
| Static portfolio | `https://mhasoneh.42.fr/portfolio/` |
| MariaDB and PHP-FPM | Internal services; no published host ports |

With the local rootless override `HTTPS_PORT=8443`, insert `:8443` after the
hostname. Evaluation uses the default 443. Configure the domain on the browser
machine: `/etc/hosts` maps `mhasoneh.42.fr` to `127.0.0.1` locally or the reachable
VM IP. This requires administrator access. Use an exception for the self-signed
development certificate on your own site, or trust its public certificate.
Port 80 is not published; enter an explicit `https://` URL.

## Starting and stopping

From the repository root:

```sh
make                 # prepare, build, start, wait for health
make ps              # show service status
make stop            # stop without removing containers
make start           # start stopped containers and wait
make restart         # restart and wait
make down            # remove containers/network; retain data
make                 # recreate using stored data and credentials
```

`make setup` prepares configuration without Docker. `make build` builds without
starting. `make clean` equals `make down`. `make re` rebuilds without cache and
restarts while preserving stored data. The first build needs Internet access.
Setup may invoke sudo to create `/home/mhasoneh/data` if your account cannot.

**`make fclean CONFIRM=DELETE` permanently deletes this stack's database,
WordPress files/uploads, volume definitions, .env, and four password files.**
Images and empty host directories remain. Back up privately first; this is not
a troubleshooting command for valuable data.

## Credentials and administration

```sh
make credentials
# Explicit disclosure in your private terminal only:
cat secrets/wp_admin_password.txt
```

Log in as `mhasoneh`. The second account, `editor42`, uses
`secrets/wp_user_password.txt`. It can manage content but cannot administer the
installation. No default/shared passwords exist. Normal startup does not display
passwords. MariaDB root credentials are not needed for site use.

`secrets/` is mode 700; its files are mode 600 and ignored by Git. Keep a private
backup outside the repository. Rebuilds and restarts preserve passwords. Deleting
a secret is not a password reset: setup refuses to replace it beside stored data.
Restore the original secret from backup.

WordPress administration can change an account's password in the database.
Update its local secret file to match (bootstrap accepts 64 lowercase hexadecimal
characters), retaining mode 600, so credential retrieval remains accurate.
Startup never resets an existing user's password. See the developer guide for a
coordinated rotation procedure.

Create a post under **Posts → Add New** and upload an image under **Media → Add
New**. Both survive `make down` followed by `make`. The portfolio is edited in
source and rebuilt; it has no dashboard.

## Health and troubleshooting

```sh
make ps
make logs             # follow logs; Ctrl-C exits the viewer
make config           # validate Compose syntax
```

All four containers should report `healthy`. MariaDB health performs an
authenticated query; WordPress checks PHP-FPM's FastCGI ping; NGINX checks HTTPS;
the portfolio checks its HTTP server. Healthchecks report status. Docker's
restart policy restarts exited processes, not merely unhealthy ones.

| Symptom | Action |
| --- | --- |
| Cannot connect to Docker | Start the daemon; check `docker info`, context, and user access. Do not make the socket world writable. |
| Port 443 permission denied | Rootless Docker may forbid privileged ports. Use local `HTTPS_PORT=8443`; retain 443 for VM evaluation. |
| Port already allocated | Stop the conflicting host service or stack. |
| Wrong website/domain missing | Fix the browser machine's hosts entry, VM address, or port forwarding. |
| Certificate warning | Expected for self-signed TLS. Verify the domain and use an exception or trust the public certificate. |
| Database fails readiness | Inspect MariaDB logs and restore original credentials if lost. Do not delete data. |
| NGINX returns 502 | Check WordPress health/logs and service DNS; `make restart` retries startup. |
| Login fails | Check URL/port and credentials. Clear old cookies after moving domains or restoring data. |
| Data permissions fail | Use a local Linux filesystem. Let services own their data; avoid `chmod 777` and manual recursive ownership changes. |
| Missing secret beside data | Restore the matching private backup. Setup stops to protect existing data. |

Certificates survive restarts and regenerate on container recreation, so browser
trust may need updating. Placeholder emails receive no mail; SMTP/public TLS are
outside this project. Never publish secrets, cookies, backups, or private keys.
See [VALIDATION.md](docs/VALIDATION.md) for executed tests and remaining limits.
