# User documentation

## Current status

This repository contains a directory scaffold and documentation. The services,
startup commands, administration interface, and health checks are not implemented.
There is currently no running application provided by this repository.

## Planned services

| Service | Intended role |
| --- | --- |
| NGINX | HTTPS entry point using TLS 1.2 or TLS 1.3 |
| WordPress with PHP-FPM | Website and administration interface |
| MariaDB | Persistent WordPress database |
| Static website | Optional bonus website, after the mandatory stack is complete |

## Starting and stopping

The Makefile and Compose file are empty. Start, stop, rebuild, and cleanup commands
will be documented here once implemented and verified. There are no working
lifecycle commands at this stage.

## Website and administration access

The intended website address is `https://mhasoneh.42.fr`, with WordPress
administration at `https://mhasoneh.42.fr/wp-admin/`. These are planned addresses,
not available endpoints. Domain resolution and TLS setup are still pending.

## Credentials

Actual credentials will be created locally by the operator under `secrets/`.
Local environment configuration will live in `srcs/.env`. Both locations are
ignored by Git. No credentials, default passwords, or accounts are supplied.

The environment example is currently empty. The exact credential file names,
account setup, permissions, and credential rotation procedure will be documented
when the services are implemented. Never paste credentials into issues or logs.

## Service checks and persistent data

No health checks are available yet. This guide will later describe how to inspect
container status, review redacted logs, verify HTTPS, and check database access.

The intended persistent database and WordPress data location is
`/home/mhasoneh/data` on the VM host, backed by the required named Docker volumes.
No volumes or data directories have been provisioned by this scaffold.

## Getting help

See [SUPPORT.md](SUPPORT.md) for questions and troubleshooting and
[SECURITY.md](SECURITY.md) for vulnerability reporting.
