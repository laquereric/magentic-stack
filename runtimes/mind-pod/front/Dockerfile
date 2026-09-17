# mind-pod FRONT: thin overlay on front-base. Core stays at /.
# Notes are served at /notes.html and reach BACK through CPCP note.* .
#
# FRONT_BASE is the LOCAL tag, not a digest. FLOOR-FRONT.json says in as many
# words: "Do not invent a registry digest. Do not auto-bump." front-base's
# source changed when the overlay-hooks loader landed, so the digest recorded
# there (sha256:6691de3d) no longer describes this base. Rebuild front-base,
# re-measure, and pin here only once a human has updated FLOOR-FRONT.json.
ARG FRONT_BASE=front-base:local
FROM ${FRONT_BASE}
USER root
WORKDIR /opt/magentic/front
COPY notes.html notes.js hooks.js src/overrides/
ENV FRONT_OVERRIDE=/opt/magentic/front/src/overrides
USER bun
EXPOSE 3000
CMD ["bun", "run", "src/server.js"]
