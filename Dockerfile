# syntax=docker/dockerfile:1.7
ARG HINDSIGHT_IMAGE=ghcr.io/vectorize-io/hindsight:latest-slim
FROM ${HINDSIGHT_IMAGE}

COPY upstream/hindsight-extensions/static-keys-tenant/hindsight_ext_static_keys_tenant /app/extensions/hindsight_ext_static_keys_tenant
COPY upstream/hindsight-extensions/bank-llm-routing/hindsight_ext_bank_llm_routing /app/extensions/hindsight_ext_bank_llm_routing
ENV PYTHONPATH=/app/extensions

RUN /app/api/.venv/bin/python -c "import hindsight_ext_static_keys_tenant, hindsight_ext_bank_llm_routing"
