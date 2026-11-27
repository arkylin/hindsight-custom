# syntax=docker/dockerfile:1.7
ARG HINDSIGHT_IMAGE=ghcr.io/vectorize-io/hindsight:latest-slim
FROM ${HINDSIGHT_IMAGE}

ARG HINDSIGHT_VARIANT=full

COPY upstream/hindsight-extensions/static-keys-tenant/hindsight_ext_static_keys_tenant /app/extensions/hindsight_ext_static_keys_tenant
COPY upstream/hindsight-extensions/bank-llm-routing/hindsight_ext_bank_llm_routing /app/extensions/hindsight_ext_bank_llm_routing
COPY --chown=1000:1000 scripts/prepare-local-models.py /tmp/prepare-local-models.py
ENV PYTHONPATH=/app/extensions

RUN /app/api/.venv/bin/python -c "import hindsight_ext_static_keys_tenant, hindsight_ext_bank_llm_routing"

# Full keeps only the models this deployment actually uses. The 1.5 GB
# EmbeddingGemma knowledge-bank model and the default BGE model are removed;
# Knowledge Banks are configured to reuse the text-only hs-embed-1 model.
RUN if [ "$HINDSIGHT_VARIANT" = "full" ]; then \
      HF_HUB_DISABLE_PROGRESS_BARS=1 /app/api/.venv/bin/python /tmp/prepare-local-models.py \
      && test -d /home/hindsight/.cache/huggingface/hub/models--hindsight-ai--hs-embed-1 \
      && test -d /home/hindsight/.cache/huggingface/hub/models--hindsight-ai--hs-rerank-1 \
      && test ! -d /home/hindsight/.cache/huggingface/hub/models--google--embeddinggemma-2 \
      && test ! -d /home/hindsight/.cache/huggingface/hub/models--BAAI--bge-small-en-v1.5; \
    fi \
    && rm -f /tmp/prepare-local-models.py

ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1
