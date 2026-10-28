# Developer documentation

## Current status

The repository provides the project structure and documentation. The Makefile,
Compose configuration, Dockerfiles, `.dockerignore` files, and `.env.example` are
empty. There are no application scripts or working build targets.

## Environment preparation

The implementation will require a Linux virtual machine with Git, Make, Docker
Engine, and the Docker Compose plugin. Basic tool availability can be checked with:

```sh
git --version
make --version
docker --version
docker compose version
```

Read the [local subject](inception_subject.txt) and confirm it matches the version
assigned on Intra. Use `mhasoneh.42.fr` as the project domain and
`/home/mhasoneh/data` as the required host data location.

## Source layout

- `srcs/docker-compose.yml`: future stack definition.
- `srcs/requirements/mariadb/`: Dockerfile, database configuration, and tools.
- `srcs/requirements/wordpress/`: Dockerfile, PHP/WordPress configuration, and tools.
- `srcs/requirements/nginx/`: Dockerfile and NGINX configuration.
- `srcs/requirements/bonus/static_site/`: Dockerfile, configuration, and website files.

Empty source directories contain `.gitkeep` so Git preserves them. Remove a
directory's `.gitkeep` when adding actual files there.

## Configuration and secrets

Create `srcs/.env` only when configuration variables have been defined. Update
`srcs/.env.example` with non-sensitive example values at that time. Never copy real
credentials into an example file.

The local `secrets/` directory is ignored in full and will not be present in a
fresh clone. Recreate it locally when preparing credentials. Secret file names,
permissions, and their Compose mappings remain to be defined; no fake credentials
or passwords are provided.

`.gitignore` also excludes environment variants, local keys and certificates,
runtime data, backup directories, logs, editor state, and local Compose overrides.
Private database exports belong under an ignored `backups/` directory; SQL source
files are deliberately not globally ignored. Ignore rules do not untrack files
that have already been committed, and do not protect Docker build contexts.
Service `.dockerignore` files still need to be configured during implementation.

## Build, launch, and container management

No build, launch, container management, or cleanup commands are implemented yet.
Do not expect `make` or the empty Compose file to start a stack. Document the
actual commands here alongside their implementation and validation results.

The eventual Makefile must invoke the Compose definition under `srcs/` and build
the project's own service images. See [the roadmap](docs/ROADMAP.md) for remaining
work and [the architecture plan](docs/ARCHITECTURE.md) for intended boundaries.

## Data and persistence

Two named Docker volumes are required: one for the WordPress database and one for
WordPress files. Their data must end up under `/home/mhasoneh/data` on the VM host,
as required by the local subject. Their configuration, backup/restore commands,
and destructive cleanup behavior are still pending. No runtime storage exists as
part of the scaffold.

## Reviewing changes

Read [CONTRIBUTING.md](CONTRIBUTING.md). For documentation changes, check relative
links and ensure descriptions match the repository's current behavior. For later
runtime changes, record the relevant build and service checks in the pull request.
No automated test suite or CI workflow is configured at this stage.
