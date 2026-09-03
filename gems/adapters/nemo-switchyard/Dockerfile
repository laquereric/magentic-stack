# ROLE=switch v1 image. ADR 0038: this adapter is the only build file
# allowed to reach the pin source.
#
# submodule_path is read from upstreams/manifests/nemo-switchyard.pin.json
# (field submodule_path). Shape D: rust pin + Node leftover in ONE
# compose service. No new published ports. 4000 stays loopback inside
# this container; Node reverse-fronts it on unpublished 8789.
#
# Keep RUST_VERSION in sync with the pin's rust-toolchain.toml.
ARG RUST_VERSION=1.96.1
FROM rust:${RUST_VERSION}-bookworm AS builder

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
