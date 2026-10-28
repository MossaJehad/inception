# Changelog

Changes are recorded here before the first release. No versions have been released.

## Unreleased

### Added

- Service directory scaffold for MariaDB, WordPress, NGINX, and a bonus static site.
- Empty Dockerfile, Docker ignore, Compose, and environment example placeholders.
- Git preservation markers for empty source directories.
- README, user/developer guides, architecture plan, roadmap, and documentation index.
- Code of conduct, contribution guide, security policy, support guide, and MIT license.
- GitHub issue and pull request templates.

### Changed

- Moved the environment example into `srcs/`.
- Expanded Git ignore rules for local secrets, environment variants, keys,
  certificates, runtime data, backups, logs, overrides, and editor files.

### Implemented

- Four custom Debian service builds, private networking, two host-backed named volumes.
- Generated configuration/secrets, idempotent database/site initialization, healthchecks.
- HTTPS/FastCGI routing, static portfolio bonus, and safe Make lifecycle targets.
- Disposable integration/persistence/security tests and full operational documentation.
- Fixed WP-CLI prompt password disclosure; rotated the affected local test accounts.

### Pending

- Final Linux VM evaluation, default privileged host-port check, and VM reboot validation.
