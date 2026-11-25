# hindsight-custom

Custom **Hindsight** image built from the newest upstream tag, with the
`static-keys-tenant` extension baked in.

- GitHub repository: <https://github.com/arkylin/hindsight-custom>
- GHCR image/package: `ghcr.io/arkylin/hindsight` (the package name does not
  follow a repository rename)

Upstream: <https://github.com/vectorize-io/hindsight>

## Image

```
ghcr.io/arkylin/hindsight:latest
ghcr.io/arkylin/hindsight:v1.3.0   # upstream tag
ghcr.io/arkylin/hindsight:1.3.0    # same image, version without v
```

Built on `ghcr.io/vectorize-io/hindsight:<version>-slim` (linux/amd64).
The extension source is copied from the same upstream tag; no third-party
dependencies are added.

## Workflow

`.github/workflows/build.yml` runs:

- **Daily at 09:00 Asia/Shanghai** (`0 1 * * *` UTC) and on manual dispatch.
- Resolves the newest stable upstream tag from
  `repos/vectorize-io/hindsight/tags` (semver `vX.Y.Z`, `sort -V`).
- Checks whether `ghcr.io/arkylin/hindsight:<tag>` already exists; if so, skips
  the build.
- Otherwise checks out upstream at that tag and runs
  `hindsight-extensions/static-keys-tenant/Dockerfile`.
- Pushes `<tag>`, `<version>` and `latest`.
- Prunes GHCR versions through `gh api`: keeps every version newer than
  3 days, and always keeps the newest version even if it is already older than
  3 days; among versions older than 3 days only that newest one survives.
  Any version carrying the `latest` tag is also kept.

Manual trigger:

```bash
gh workflow run build.yml -R arkylin/hindsight-custom -f force=true
gh workflow run build.yml -R arkylin/hindsight-custom -f tag=v1.3.0 -f force=true
```

## Run

```bash
docker run -d --name hindsight \
  --restart unless-stopped --shm-size=1g \
  -p 127.0.0.1:28888:8888 -p 127.0.0.1:29999:9999 \
  -e HINDSIGHT_API_TENANT_EXTENSION=hindsight_ext_static_keys_tenant:StaticKeysTenantExtension \
  -e HINDSIGHT_API_TENANT_USERS='me:key1,me:key2' \
  -v hindsight-data:/home/hindsight/.pg0 \
  ghcr.io/arkylin/hindsight:latest
```

With `static-keys-tenant`, each `user` gets its own Postgres schema
(`user_<id>`); multiple keys may map to the same user. Unknown keys get 401.
See the upstream extension README for all options.

## Notes

- The image is public so it can be pulled through mirrors (for example
  `ghcr.nju.edu.cn/arkylin/hindsight:latest`).
- Repository artifact/log retention is set to 3 days.
- This repository only builds the image; deployment configuration lives with
  the deployment, not here.
