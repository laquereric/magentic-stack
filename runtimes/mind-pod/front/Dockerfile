# mind-pod FRONT: thin overlay on front-base. Core stays at /.
# Notes are served at /notes.html and reach BACK through CPCP note.* .
#
# FRONT_BASE IS NOW A PUBLISHED, MULTI-ARCH REF. This said the base "stays one
# LOCAL tag" because FROM front-base@sha256:<id> did not resolve for a
# never-pushed image -- measured 2026-09-17, exit 1. publish-images has since
# shipped front-base for linux/amd64 and linux/arm64, so the digest form
# resolves and the tag form is no longer forced. FLOOR-FRONT.json carries the
# index digest; this default names the tag that points at it so a bare
# `docker build` works without compose supplying the arg.
ARG FRONT_BASE=ghcr.io/laquereric/magentic-stack/front-base:sha-31db447f23aa34fde6f92bc862b0534bc44eb47c
FROM ${FRONT_BASE}
USER root
WORKDIR /opt/magentic/front
COPY notes.html notes.js hooks.js src/overrides/
ENV FRONT_OVERRIDE=/opt/magentic/front/src/overrides
USER bun
EXPOSE 3000
CMD ["bun", "run", "src/server.js"]
