# syntax=docker/dockerfile:1.7
FROM groonga/pgroonga:4.1.0-debian-18@sha256:55f246f1137e194d830ffac88a22f4d3e8023bcebb3bc0b36eb8732e322c9dc2

LABEL org.opencontainers.image.title="Hindsight PostgreSQL" \
      org.opencontainers.image.description="PostgreSQL 18.6 with pgvector 0.8.7 and PGroonga 4.1.0"

ADD --checksum=sha256:d9923b9ea81375604d88bfcfa167d58bfaf3de5689372c9e4504244f1671f596 \
    https://apt.postgresql.org/pub/repos/apt/pool/main/p/pgvector/postgresql-18-pgvector_0.8.7-1.pgdg13+1_amd64.deb \
    /tmp/postgresql-18-pgvector.deb

RUN dpkg -i /tmp/postgresql-18-pgvector.deb \
    && rm -f /tmp/postgresql-18-pgvector.deb
