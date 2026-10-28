*This project has been created as part of the 42 curriculum by mhasoneh.*

# Inception

## Description

Inception is a system administration project for learning Docker, service isolation,
networking, HTTPS, and persistent storage inside a virtual machine.

**Status: directory scaffold and documentation only.** The Makefile, Compose file,
Dockerfiles, Docker ignore files, and environment example are empty placeholders.
No services can be built or started from this repository yet.

The planned mandatory stack consists of NGINX, WordPress with PHP-FPM, and MariaDB.
A separate static website is planned as a bonus after the mandatory part works.

## Instructions

Clone the repository and read the documentation:

```sh
git clone https://github.com/MossaJehad/inception.git
cd inception
```

Start with [USER_DOC.md](USER_DOC.md) for the current user-facing status and
[DEV_DOC.md](DEV_DOC.md) for development preparation. Build and launch instructions
will be added when the implementation exists; `make` does not launch anything yet.

The intended environment is a Linux virtual machine with Git, Make, Docker Engine,
and the Docker Compose plugin. The project domain will be `mhasoneh.42.fr`, and
persistent data must end up under `/home/mhasoneh/data` on the VM host.

## Project description

The planned design follows the [local subject, version 5.4](inception_subject.txt).
Configuration sources belong in `srcs/`; the Makefile and required documentation
remain at the root. Each service will be built from its own Dockerfile using a
permitted Alpine or Debian base, with exact versions selected during implementation.
Ready-made service images and the `latest` tag are prohibited by the subject.

| Location | Purpose |
| --- | --- |
| `Makefile` | Future build and lifecycle entry point |
| `srcs/docker-compose.yml` | Future service, network, volume, and secret definitions |
| `srcs/.env.example` | Future sanitized configuration example; currently empty |
| `srcs/requirements/mariadb/` | Database Dockerfile, configuration, and tools |
| `srcs/requirements/wordpress/` | WordPress/PHP-FPM Dockerfile, configuration, and tools |
| `srcs/requirements/nginx/` | HTTPS entry point Dockerfile and configuration |
| `srcs/requirements/bonus/static_site/` | Bonus Dockerfile, configuration, and site content |
| `secrets/` | Local credentials; ignored by Git and currently empty |

### Virtual Machines vs Docker

A virtual machine runs a guest operating system with its own kernel. Containers
isolate processes while sharing their host kernel. This project will use a VM as
the host and separate containers for the services.

### Secrets vs Environment Variables

Environment variables provide runtime configuration. The planned `srcs/.env` will
remain local, with sanitized variable names documented in `.env.example` later.
Docker secrets will provide confidential values as mounted files, keeping their
contents out of image layers and the repository. Secret files will live locally in
`secrets/`; no credentials are supplied here.

### Docker Network vs Host Network

A dedicated Docker network lets containers communicate through service names while
controlling published ports. Host networking shares the host network namespace.
The planned stack will use a dedicated network; host networking is forbidden by
the subject. NGINX will expose the mandatory stack through HTTPS on port 443 only.

### Docker Volumes vs Bind Mounts

Docker manages named volumes independently of a container's writable layer. Bind
mounts directly expose a selected host path. The local subject requires two named
volumes for database and WordPress data, with data ending up under
`/home/mhasoneh/data`; it prohibits substituting bind mounts for these volumes.
The storage configuration is still to be implemented and verified.

## Documentation and community

See the [documentation index](docs/README.md) for the full reading list, including
the user/developer guides, architecture, roadmap, and community policies.

- [Code of conduct](CODE_OF_CONDUCT.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Changelog](CHANGELOG.md)
- [MIT license](LICENSE)

## Resources

- [Local Inception subject](inception_subject.txt) — requirements used by this repository;
  check the subject assigned on Intra before evaluation.
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Docker volume documentation](https://docs.docker.com/engine/storage/volumes/)

### AI assistance

AI assistance was used to inspect and prepare the directory structure and draft
repository documentation and ignore rules. The learner remains responsible for
reviewing these materials and understanding the eventual implementation.

## License

Original project work is licensed under the [MIT License](LICENSE).
The 42 subject and third-party software retain their respective terms.
