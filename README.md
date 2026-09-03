# Seafile + Traefik + Let's Encrypt on Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository deploys **Seafile Community Edition 13** (fast, reliable file sync and share) behind **Traefik** with automatic **Let's Encrypt TLS**, backed by **MariaDB 11.4 LTS** and **Redis**, with scheduled **backups** (all three Seafile databases + file data) and companion **restore scripts**.

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose
cd seafile-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create seafile-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: admin email + password, two DB passwords, the JWT key,
#   SEAFILE_HOSTNAME, TRAEFIK_HOSTNAME, TRAEFIK_ACME_EMAIL,
#   TRAEFIK_BASIC_AUTH.

# 4. Deploy
docker compose -f seafile-traefik-letsencrypt-docker-compose.yml -p seafile up -d
```

First start installs the databases: give it a few minutes, then log in at `https://${SEAFILE_HOSTNAME}` with the admin credentials from `.env`. Desktop and mobile clients use the same URL.

### What success looks like

```bash
docker compose -f seafile-traefik-letsencrypt-docker-compose.yml -p seafile ps
curl -fskL -o /dev/null -w "%{http_code}\n" "https://${SEAFILE_HOSTNAME}/accounts/login/"   # 200
curl -fsk "https://${SEAFILE_HOSTNAME}/seafhttp/protocol-version"   # {"version": 2}
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet.
- **502 in the first minutes.** Database installation is still running; watch `docker logs seafile-seafile-1` until "Seahub is started".
- **`docker compose up` fails with `set in .env`.** A required variable is empty: Seafile 12+ requires the JWT key; the error names what's missing.
- **Networks not found.** Step 2 was skipped.

## Supply chain trust

Four images ([`traefik`](https://hub.docker.com/_/traefik), [`seafileltd/seafile-mc`](https://hub.docker.com/r/seafileltd/seafile-mc), [`mariadb`](https://hub.docker.com/_/mariadb), [`redis`](https://hub.docker.com/_/redis)) pinned to `tag@sha256:<digest>` as interpolation defaults in the compose `x-images` block. `git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

Two override levels exist per image. `<PREFIX>_IMAGE_VERSION` in `.env` swaps only the version of that image (Compose then pulls the tag, without a digest) and leaves every other pin as tested; `<PREFIX>_IMAGE_TAG` replaces the whole reference, digest included. The variable names are listed in `.env.example`. Nested defaults need Docker Compose v2.5 or newer (2022); v2.0 to v2.4 leave the inner `${...}` unexpanded and `docker compose up` fails with an invalid reference instead of deploying something unexpected.

The daily `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned Seafile and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Strong secrets**: both DB passwords, the admin password, and the JWT key; regenerate the Traefik dashboard hash.
- [ ] **Host-mount the backup volumes** for disaster recovery: file data and the databases are only useful restored together.
- [ ] **Upgrade one major at a time**: Seafile migrates its schema per major; back up before each step.
- [ ] **Verify Let's Encrypt cert issuance** in the Traefik logs on first start.

## Backups and restore

The `backups` container dumps Seafile's three databases (`ccnet_db`, `seafile_db`, `seahub_db`) and tars `/shared` on a schedule (defaults: 30-minute warm-up, 24-hour interval, 7-day retention). Restore with the interactive scripts (`chmod +x *.sh` once): `./seafile-restore-database.sh`, then `./seafile-restore-application-data.sh`.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults: the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/seafile-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: shellcheck + actionlint, Trivy scans of all four pinned images, the weekly freshness check, and a deploy-and-test job that boots the stack with ephemeral credentials and requires the login page and the `/seafhttp` endpoint through Traefik.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the HTTPS smoke. The scenario that matters most is the restore roundtrip: insert a marker row, restore the earliest backup, assert the marker is gone. A backup that cannot be restored fails the build. Run it yourself against a running deployment with short intervals in `.env` (`BACKUP_INIT_SLEEP=15s`, `BACKUP_INTERVAL=60s`):

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

It stops the database container briefly to prove failure detection: run it on a staging copy, not on production.

## Security Notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-09-01) shipped a tracked `.env` with generated-looking passwords. Rotate them if your deployment reused them.
- MariaDB and Redis listen only on the internal network.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
