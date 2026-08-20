# SwitchYard: the pod's LLM plane. Owns sources, keys and routing so MIND holds
# no credential and names no model.
#
# Build context is runtimes/mind-pod/.. (the repo root) because this image reuses
# the vendored SwitchYard.offline gate from apps/switchyard-offline/shared.
FROM node:20-slim
WORKDIR /switch
COPY runtimes/switch/ ./
COPY apps/switchyard-offline/shared/ /apps/switchyard-offline/shared/
ENV SWITCH_STATE_DIR=/state
EXPOSE 8789 8790
CMD ["node", "server.mjs"]
