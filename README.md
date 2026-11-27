# hindsight-custom

Custom **Hindsight** images built from the newest upstream tag, with the
`static-keys-tenant` and `bank-llm-routing` extensions baked in. Each published
tag is a separate, minimal installation:

- **Full/local** (`latest`): the upstream `local-ml` stack for local PyTorch
  embeddings/reranking.
- **ONNX** (`latest-onnx`): only the `local-onnx` stack (ONNX Runtime +
  tokenizer), with no PyTorch or sentence-transformers.
- **Slim** (`latest-slim`): core only, for external embedding/reranking APIs.

- GitHub repository: <https://github.com/arkylin/hindsight-custom>
- GHCR image/package: `ghcr.io/arkylin/hindsight` (the package name does not
  follow a repository rename)

Upstream: <https://github.com/vectorize-io/hindsight>

## Image variants

| Variant | GHCR tags | Installed ML stack | When to use |
| --- | --- | --- | --- |
| **Full/local** (`latest`) | `latest`, `vX.Y.Z`, `X.Y.Z` | Upstream `local-ml`: torch, torchvision, sentence-transformers, transformers, safetensors. Upstream's optional `flashrank` backend pulls `onnxruntime` transitively. | Local PyTorch embeddings/reranking. |
| **ONNX** (`latest-onnx`) | `latest-onnx`, `vX.Y.Z-onnx`, `X.Y.Z-onnx` | Only `local-onnx`: onnxruntime, transformers, tokenizers, huggingface-hub, numpy. Build fails if torch, sentence-transformers, or flashrank is present. | Local ONNX embeddings/reranking. |
| **Slim** (`latest-slim`) | `latest-slim`, `vX.Y.Z-slim`, `X.Y.Z-slim` | Core only: no torch, onnxruntime, sentence-transformers, or flashrank. | External embeddings/reranking providers (OpenAI, Cohere, TEI). |

All variants are built for `linux/amd64`, include both extensions, and contain
**no model weights**. The Full and ONNX variants mount a model cache from the
host; Slim uses external APIs.

```text
ghcr.io/arkylin/hindsight:latest          # Full/local
ghcr.io/arkylin/hindsight:latest-onnx     # ONNX-only
ghcr.io/arkylin/hindsight:latest-slim     # Slim/core-only
ghcr.io/arkylin/hindsight:v1.3.0          # Full/local, upstream tag
ghcr.io/arkylin/hindsight:1.3.0           # Full/local, version without v
ghcr.io/arkylin/hindsight:v1.3.0-onnx     # ONNX-only, upstream tag
ghcr.io/arkylin/hindsight:1.3.0-onnx      # ONNX-only, version without v
ghcr.io/arkylin/hindsight:v1.3.0-slim     # Slim, upstream tag
ghcr.io/arkylin/hindsight:1.3.0-slim      # Slim, version without v
```

The Full/local tag follows the upstream `local-ml` extra, so its optional
`flashrank` dependency may install `onnxruntime`; that is the local reranker's
optional backend, not the ONNX provider. Use `latest-onnx` when the image must
contain only the ONNX runtime stack.

## ONNX tags

`.github/workflows/build.yml` builds the ONNX tag from the upstream source
Dockerfile with `INCLUDE_LOCAL_MODELS=false`, then installs only the
`local-onnx` dependencies:

```text
onnxruntime>=1.17.0
transformers>=5.22.1
tokenizers>=0.23.1,<0.24.0
huggingface-hub>=0.20.0
numpy>=1.26.0
```

The Dockerfile stage asserts that `torch`, `sentence_transformers`, and
`flashrank` are absent; a build that leaks any of them fails. The image still
contains the API and control plane, but no PyTorch runtime or local PyTorch
model weights. Model weights are mounted at runtime; none are baked in.

For `hs-embed-1` and `hs-rerank-1`, keep the ONNX preprocessing identical to
the local PyTorch path:

```bash
# Embeddings: 384 dimensions, mean pooling, no prompts, not normalized
HINDSIGHT_API_EMBEDDINGS_PROVIDER=onnx
HINDSIGHT_API_EMBEDDINGS_ONNX_MODEL_ID=hindsight-ai/hs-embed-1
HINDSIGHT_API_EMBEDDINGS_ONNX_DIMENSIONS=384
HINDSIGHT_API_EMBEDDINGS_ONNX_MAX_TOKENS=8192
HINDSIGHT_API_EMBEDDINGS_ONNX_POOLING=mean
HINDSIGHT_API_EMBEDDINGS_ONNX_NORMALIZE=false
HINDSIGHT_API_EMBEDDINGS_ONNX_QUERY_PREFIX=
HINDSIGHT_API_EMBEDDINGS_ONNX_PASSAGE_PREFIX=

# Reranker: raw logits; batch 8 measured faster than the default 32 on 4 CPUs
HINDSIGHT_API_RERANKER_PROVIDER=onnx
HINDSIGHT_API_RERANKER_ONNX_MODEL_ID=hindsight-ai/hs-rerank-1
HINDSIGHT_API_RERANKER_ONNX_MAX_TOKENS=8192
HINDSIGHT_API_RERANKER_ONNX_BATCH_SIZE=8
HINDSIGHT_API_RERANKER_ONNX_MAX_CONCURRENT=1
```

Leaving the ONNX defaults is **not** compatible with the existing database:
the defaults add `query: ` / `passage: ` prefixes and normalize the output.
On `hs-embed-1` that changes the vector space (measured mean cosine 0.9805 and
7-9/10 top-10 overlap instead of 0.9999 and 9-10/10). The reranker ONNX default
`MAX_TOKENS=512` also differs from the local model's 8192.

## Workflow

`.github/workflows/build.yml` runs:

- **Daily at 09:00 Asia/Shanghai** (`0 1 * * *` UTC) and on manual dispatch.
- Resolves the newest stable upstream tag from
  `repos/vectorize-io/hindsight/tags` (semver `vX.Y.Z`, `sort -V`).
- Builds Full/local, ONNX, and Slim as separate matrix jobs. Each variant is
  skipped only when its own custom tag already exists with the expected variant
  label.
- Full/local is built from the upstream source with `INCLUDE_LOCAL_MODELS=true`
  and `PRELOAD_ML_MODELS=false`.
- ONNX is built from the upstream source with `INCLUDE_LOCAL_MODELS=false` and
  `PRELOAD_ML_MODELS=false`, target `hindsight-onnx`, then installed with only
  `local-onnx`.
- Slim is built from the upstream `-slim` base plus the extensions.
- Publishes `latest`, `vX.Y.Z` and `X.Y.Z` for Full, `latest-onnx`,
  `vX.Y.Z-onnx` and `X.Y.Z-onnx` for ONNX, and `latest-slim`, `vX.Y.Z-slim` and
  `X.Y.Z-slim` for Slim, for `linux/amd64`.
- Prunes GHCR versions through `gh api`: keeps every version newer than
  3 days, the newest version, and any version carrying `latest`,
  `latest-slim`, or `latest-onnx`; other older versions are deleted.

No tag is an alias of another. The ONNX image is a real build with its own
dependency boundary.

Manual trigger:

```bash
gh workflow run build.yml -R arkylin/hindsight-custom -f force=true
gh workflow run build.yml -R arkylin/hindsight-custom -f tag=v1.3.0 -f force=true
```

## Run

Full/local (default):

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

ONNX-only: replace the final image with
`ghcr.io/arkylin/hindsight:latest-onnx`, mount the ONNX model cache at
`/home/hindsight/.cache/huggingface` (read-only is recommended), and set the
provider variables above.

Slim: replace the final image with
`ghcr.io/arkylin/hindsight:latest-slim` and configure external embeddings and
reranking providers. Slim has no local ML runtime.

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
  `ghcr.nju.edu.cn/arkylin/hindsight:latest-onnx`).
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
