# Planned architecture

## Status

This is an implementation plan based on the [local subject](../inception_subject.txt),
not a description of a deployed system. All runtime configuration is pending.

## Service boundaries and traffic

```text
Client
  |
  | HTTPS:443, mhasoneh.42.fr
  v
NGINX ----> WordPress / PHP-FPM ----> MariaDB
                |                      |
                v                      v
        WordPress named volume   Database named volume
```

Each service will run in its own container, built from its own Dockerfile using
an allowed Alpine or Debian base. NGINX will be the mandatory stack's single
entry point, accepting TLS 1.2 or TLS 1.3 on port 443. WordPress/PHP-FPM and MariaDB
will communicate over a dedicated Docker network without public service ports.

Container restart behavior and proper foreground processes remain to be
configured. Host networking, legacy links, and artificial keep-alive loops are
prohibited by the local subject.

## Persistent storage

Two named Docker volumes will persist WordPress files and the database separately.
The local subject requires their data to end up under `/home/mhasoneh/data` on the
VM host and prohibits replacing these with bind mounts. Exact volume definitions
and verification of their host storage remain implementation work.

## Configuration boundaries

Non-sensitive examples will be documented in `srcs/.env.example`. Local environment
settings will live in the ignored `srcs/.env`. Confidential values will live in
ignored files under `secrets/`, with Docker secret mappings defined later.

No secret contents will be included in Dockerfiles, public examples, image layers,
or version-controlled documentation. The current `.dockerignore` files are empty;
build-context exclusions must be implemented before building the services.

## Bonus static website

The directory at `srcs/requirements/bonus/static_site/` reserves a Dockerfile,
configuration directory, and site content directory for a separate bonus container.
Its serving method and routing have not been selected. The subject excludes PHP
for this bonus. Mandatory functionality must be completed before bonus work.
