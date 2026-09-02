# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.1.0] - 2026-09-02

### Fixed

- **A failed database dump no longer produces a silent, corrupt backup.**
  The old loop piped the dump into `gzip` and only checked `gzip`'s exit
  status, so a dump that failed halfway (database down, wrong password,
  disk full) still left a small `.gz` that looked like a backup. The loop
  now runs with `pipefail`, logs `Database backup OK: <file> (<bytes>
  bytes)` or `Database backup FAILED` per cycle, keeps a failed dump as
  `<file>.failed` for diagnosis, and prunes only its own files. Retention
  set to `0` disables pruning instead of deleting everything.

### Added

- CI now waits for the first backup cycle and proves the produced
  archive is readable and contains a real dump header (plus a readable
  `tar.gz` for the data backup where the stack has one).

## [1.0.0] - 2026-09-01

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Changed (BREAKING for existing deployments)

- **Seafile 11 → 13.0.25.** Seafile 12 changed the container contract:
  the `MYSQL_*`/`SEAFILE_ADMIN`-style environment variables are dead,
  `JWT_PRIVATE_KEY` is required, the cache moved from memcached to
  Redis, and seahub now binds to localhost behind the container's
  bundled nginx. The template is rebuilt for the new contract: the
  memcached service is replaced by Redis, all three Traefik routers
  target the bundled nginx on port 80 (the old `/seafhttp` prefix
  stripping is gone — nginx expects the prefix), and `.env` gains
  `SEAFILE_JWT_PRIVATE_KEY`. ❗ Existing Seafile 11 deployments must
  upgrade majors one at a time (11 → 12 → 13) per the Seafile manual
  before adopting this compose — see the release notes.
- **MariaDB 11.4 LTS, Traefik 3.7** (3.2's Docker client cannot talk to
  Docker Engine 29), Redis 7.4 — all pinned by `tag@sha256:digest` in
  the compose `x-images` block.

### Fixed

- **The database backup could never work as written**: it ran
  `mariadb-dump --all-databases` as the non-root seafile user, which
  fails on the mysql system schema. The loop now dumps Seafile's three
  databases explicitly, and backup variables are `$$`-escaped so the
  container shell resolves them at runtime.
- Shellcheck findings in both restore scripts.

### Added

- **Deployment Verification workflow**: shellcheck + actionlint; Trivy
  scans of all four pinned images; weekly `check-pin-freshness`; and a
  deploy-and-test job that boots the stack and requires the login page
  and the `/seafhttp` file-server endpoint through Traefik.
- `.env.example`; `.env` gitignored.

[Unreleased]: https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
