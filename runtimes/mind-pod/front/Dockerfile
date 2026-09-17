# mind-pod FRONT: thin overlay on front-base. Core stays at /.
# Notes are served at /notes.html and reach BACK through CPCP note.* .
#
# FRONT_BASE is the LOCAL tag and stays one. FROM front-base@sha256:<id> does
# NOT resolve for a never-pushed local image -- tested 2026-09-17, digest form
# exits 1 while the tag form exits 0 -- so a digest pin is not available here
# until publish-images ships front-base to GHCR. The human pin lives in
# FLOOR-FRONT.json, re-measured 2026-09-17 to sha256:fcb9d002 at rev c44c62e.
ARG FRONT_BASE=front-base:local
FROM ${FRONT_BASE}
USER root
WORKDIR /opt/magentic/front
COPY notes.html notes.js hooks.js src/overrides/
ENV FRONT_OVERRIDE=/opt/magentic/front/src/overrides
USER bun
EXPOSE 3000
CMD ["bun", "run", "src/server.js"]
