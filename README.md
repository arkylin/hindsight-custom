# hindsight-custom

Custom **Hindsight** images built from the newest upstream tag, with the
`static-keys-tenant` and `bank-llm-routing` extensions baked in. Both Full and
Slim variants are published.

- GitHub repository: <https://github.com/arkylin/hindsight-custom>
- GHCR image/package: `ghcr.io/arkylin/hindsight` (the package name does not
  follow a repository rename)

Upstream: <https://github.com/vectorize-io/hindsight>

## Image variants

| Variant | GHCR tags | Size (AMD64) | Size (ARM64) | When to use |
| --- | --- | --- | --- | --- |
| **Full** (`latest`) | `latest`, `vX.Y.Z`, `X.Y.Z` | ~4.5 GB (~2.2 GB download) | ~4.4 GB (~2.1 GB download) | Default. Embeddings and reranking run in the image, and the knowledge banks' EmbeddingGemma 2 model (~1.5 GB) is bundled so they work offline; the LLM is always external, including for local inference. |
| **Slim** (`latest-slim`) | `latest-slim`, `vX.Y.Z-slim`, `X.Y.Z-slim` | ~1.4 GB (~600 MB download) | ~1.4 GB (~570 MB download) | Use when you already rely on external services for embeddings and reranking (OpenAI, Cohere, TEI). Significantly smaller image, faster deploys. Requires [external providers](https://hindsight.vectorize.io/developer/configuration#embeddings). |

Both variants are multi-arch (`linux/amd64`, `linux/arm64`) and include both
extensions. They are built from the matching upstream Full or Slim image for
the same tag; no third-party dependencies are added.

```text
ghcr.io/arkylin/hindsight:latest          # Full
ghcr.io/arkylin/hindsight:latest-slim     # Slim
ghcr.io/arkylin/hindsight:v1.3.0          # Full, upstream tag
ghcr.io/arkylin/hindsight:1.3.0           # Full, version without v
ghcr.io/arkylin/hindsight:v1.3.0-slim     # Slim, upstream tag
ghcr.io/arkylin/hindsight:1.3.0-slim      # Slim, version without v
```

## Workflow

`.github/workflows/build.yml` runs:

- **Daily at 09:00 Asia/Shanghai** (`0 1 * * *` UTC) and on manual dispatch.
- Resolves the newest stable upstream tag from
  `repos/vectorize-io/hindsight/tags` (semver `vX.Y.Z`, `sort -V`).
- Builds Full and Slim as separate matrix jobs. Each variant is skipped only
  when its own custom tag already exists with the expected variant label, so a
  legacy Slim `latest` cannot block the Full image.
- Publishes `latest`, `vX.Y.Z` and `X.Y.Z` for Full, plus `latest-slim`,
  `vX.Y.Z-slim` and `X.Y.Z-slim` for Slim, for `linux/amd64` and
  `linux/arm64`.
- Prunes GHCR versions through `gh api`: keeps every version newer than
  3 days, the newest version, and any version carrying `latest` or
  `latest-slim`; other older versions are deleted.

The first run for a given upstream tag rebuilds legacy slim-based tags as
Full because they lack the variant label. Slim is published under the
`*-slim` tags.

Manual trigger:

```bash
gh workflow run build.yml -R arkylin/hindsight-custom -f force=true
gh workflow run build.yml -R arkylin/hindsight-custom -f tag=v1.3.0 -f force=true
```

## Run

Full (default):

```bash
docker run -d --name hindsight \
  --restart unless-stopped --shm-size=1g \
  -p 127.0.0.1:28888:8888 -p 127.0.0.1:29999:9999 \
  -e HINDSIGHT_API_TENANT_EXTENSION=hindsight_ext_static_keys_tenant:StaticKeysTenantExtension \
  -e HINDSIGHT_API_TENANT_USERS='me:key1,me:key2' \
  -e HINDSIGHT_API_LLM_REQUEST_EXTENSION=hindsight_ext_bank_llm_routing:BankLLMRoutingExtension \
  -e HINDSIGHT_API_LLM_REQUEST_ROUTES='[{"bank":"*","api_key":"<gateway-key>"}]' \
  -v hindsight-data:/home/hindsight/.pg0 \
  ghcr.io/arkylin/hindsight:latest
```

For Slim, replace the final image with
`ghcr.io/arkylin/hindsight:latest-slim` and configure external embeddings and
reranking providers. Slim omits the local ML models, so it will not work with
the embedded providers.

With `static-keys-tenant`, each `user` gets its own Postgres schema
(`user_<id>`); multiple keys may map to the same user. Unknown keys get 401.
`bank-llm-routing` is independent of the tenant slot: routes match bank-id
globs and optional operation globs, first match wins, and unmatched calls are
denied unless `HINDSIGHT_API_LLM_REQUEST_UNMATCHED=server`. The catch-all route
above keeps the server's LLM key; replace it with per-bank or per-operation
routes when needed.

The images intentionally do **not** include `supabase-tenant`.

## Extensions

- `static-keys-tenant` (`TENANT`): static `user:key` pairs, one schema per user.
- `bank-llm-routing` (`LLM_REQUEST`): per-bank / per-operation LLM, model and key
  routing through a JSON route list.

See the upstream extension READMEs for the full configuration:
<https://github.com/vectorize-io/hindsight/tree/main/hindsight-extensions>.

## Notes

- The images are public so they can be pulled through mirrors (for example
  `ghcr.nju.edu.cn/arkylin/hindsight:latest-slim`).
- Repository artifact/log retention is set to 3 days.
- This repository only builds the images; deployment configuration lives with
  the deployment, not here.

## PostgreSQL image

The external PostgreSQL image used by the Agents deployment is prebuilt and
published to GHCR instead of being compiled on the server:

```text
ghcr.io/arkylin/hindsight-postgres:18.6-pgvector0.8.7-pgroonga4.1.0
```

It contains PostgreSQL 18.6, pgvector 0.8.7 and PGroonga 4.1.0. See
[`postgres/README.md`](postgres/README.md) and
`.github/workflows/build-postgres.yml`.
