# SwitchYard: the pod's LLM plane. Owns sources, keys and routing so MIND holds
# no credential and names no model.
#
# Build context is runtimes/mind-pod/.. (the repo root) because this image reuses
# the vendored SwitchYard.offline gate from gems/switchyard-offline/shared.
FROM node:20-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0
WORKDIR /switch
COPY runtimes/switch/ ./
COPY gems/switchyard-offline/shared/ /gems/switchyard-offline/shared/
ENV SWITCH_STATE_DIR=/state
EXPOSE 8789 8790
CMD ["node", "server.mjs"]
