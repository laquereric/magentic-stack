# ROLE=switch v1 image. ADR 0038: this adapter is the only build file
# allowed to reach the pin source.
#
# submodule_path is read from upstreams/manifests/nemo-switchyard.pin.json
# (field submodule_path). Shape D: rust pin + Node leftover in ONE
# compose service. No new published ports. 4000 stays loopback inside
# this container; Node reverse-fronts it on unpublished 8789.
#
# Pin rust-toolchain.toml channel 1.96.1. Digest is the OCI *index*
# (docker buildx imagetools inspect rust:1.96.1-bookworm), not a
# platform manifest. Tag-only FROM is a fail of check_base_digests.
FROM rust:1.96.1-bookworm@sha256:a339861ae23e9abb272cea45dfafde21760d2ce6577a70f8a926153677902663 AS builder

WORKDIR /opt/switchyard
# COPY path == pin.json submodule_path (upstreams/manifests/nemo-switchyard.pin.json).
COPY upstreams/nemo-switchyard/src/Cargo.toml upstreams/nemo-switchyard/src/Cargo.lock upstreams/nemo-switchyard/src/rust-toolchain.toml ./
COPY upstreams/nemo-switchyard/src/.cargo ./.cargo
COPY upstreams/nemo-switchyard/src/crates ./crates

RUN cargo build --locked --release -p switchyard-server

FROM node:20-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder \
    /opt/switchyard/target/release/switchyard-server \
    /usr/local/bin/switchyard-server

WORKDIR /switch
COPY runtimes/switch/ ./
COPY runtimes/mind-pod/app/config/llm_catalog.json /switch/llm_catalog.json
COPY gems/switchyard-offline/shared/ /gems/switchyard-offline/shared/
COPY gems/adapters/nemo-switchyard/ /adapter/
RUN chmod +x /adapter/entrypoint.sh /usr/local/bin/switchyard-server

ENV SWITCH_STATE_DIR=/state
ENV SWITCHYARD_PIN_URL=http://127.0.0.1:4000
ENV SWITCHYARD_PIN_HOST=127.0.0.1
ENV SWITCHYARD_PIN_PORT=4000
ENV SWITCHYARD_CONFIG=/tmp/switchyard.toml

EXPOSE 8789 8790
CMD ["/adapter/entrypoint.sh"]
