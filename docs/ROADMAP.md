# Roadmap

This checklist describes planned work, with no promised delivery dates. The
[assigned subject](../inception_subject.txt) remains the source of requirements.

## Repository preparation

- [x] Keep the Makefile and required guides at the root.
- [x] Prepare mandatory service and bonus static-site directories under `srcs/`.
- [x] Add empty Dockerfile, Docker ignore, Compose, and environment example files.
- [x] Ignore local secrets, environment files, keys, runtime artifacts, and editor state.
- [x] Add community documents and GitHub contribution templates.

## Mandatory implementation

- [ ] Prepare the Linux VM and select permitted, explicit base image versions.
- [ ] Define non-sensitive environment variables and local secret file mappings.
- [ ] Implement service Dockerfiles, build-context exclusions, configuration, and tools.
- [ ] Configure NGINX for HTTPS on port 443 with TLS 1.2 or TLS 1.3 only.
- [ ] Configure WordPress with PHP-FPM and the subject's required user accounts.
- [ ] Configure MariaDB and database initialization.
- [ ] Define the dedicated network and container restart behavior.
- [ ] Configure the two named volumes with data under `/home/mhasoneh/data`.
- [ ] Configure local resolution for `mhasoneh.42.fr`.
- [ ] Implement Makefile build and lifecycle targets through Compose.

## Validation and operational documentation

- [ ] Verify builds, startup, HTTPS, service communication, and crash recovery.
- [ ] Verify data persistence, storage location, and backup/restore procedures.
- [ ] Review credentials, image contents, Git contents, and runtime exposure.
- [ ] Replace pending guide sections with tested lifecycle and management commands.
- [ ] Review the assigned Intra subject and prepare to explain the implementation.

## Bonus

- [ ] Complete and validate the mandatory part first.
- [ ] Implement and document the separate static website container without PHP.
