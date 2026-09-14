# front-base: the PLATFORM Bun FRONT image. Not an app.
#
# magentic-stack builds this; consumers build a thin FRONT image FROM it
# and add a Stage override. It contains NO overlay product chrome: only
# Bun, the editor.js skeleton, 19 widget modules, Core homepage stub,
# and adapter tables (A2UI KIND_MAP copy).
#
# FLOOR-FRONT.json is a human pin of the *built* front-base digest.
# This Dockerfile pins the Bun runtime by digest. Do not auto-bump either.
#
# ADR 0071. Rails ROLE=front remains a proxy-only stopgap until an
# overlay FROMs the declared FLOOR-FRONT digest.
FROM oven/bun:1.4.2-slim@sha256:cb3bbbb08e13a4a2ff400f24c7a2a1d5efa83f6ef8544d52d95a519631e2fc61

WORKDIR /opt/magentic/front

COPY runtimes/front-base/package.json ./
COPY runtimes/front-base/src ./src

ENV MAGENTIC_FRONT_ASSETS=/opt/magentic/front/src
EXPOSE 3000
USER bun
CMD ["bun", "run", "src/server.js"]
