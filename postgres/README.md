# Hindsight PostgreSQL image

Prebuilt PostgreSQL image for the Hindsight deployment:

- PostgreSQL 18.6
- pgvector 0.8.7
- PGroonga 4.1.0
- `linux/amd64`

GHCR image:

```text
ghcr.io/arkylin/hindsight-postgres:18.6-pgvector0.8.7-pgroonga4.1.0
ghcr.io/arkylin/hindsight-postgres:18.6
ghcr.io/arkylin/hindsight-postgres:18
ghcr.io/arkylin/hindsight-postgres:latest
```

Pull:

```bash
docker pull ghcr.io/arkylin/hindsight-postgres:18.6-pgvector0.8.7-pgroonga4.1.0
```

The image uses the upstream Groonga PGroonga Debian 18 image as its base and
adds the matching pgvector Debian package. Both the base image digest and the
pgvector package checksum are pinned in the Dockerfile.

The image is published by
`.github/workflows/build-postgres.yml` on changes under `postgres/`.

Build locally:

```bash
docker build -t hindsight-postgres:local ./postgres
```

The upstream image uses `PGDATA=/var/lib/postgresql/18/docker`; mount the
persistent volume or bind directory at `/var/lib/postgresql`.
