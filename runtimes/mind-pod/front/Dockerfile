# mind-pod FRONT: thin overlay on front-base. Core is the homepage.
# Notes nest at /notes. Same skeleton digest as sharedai.space.
ARG FRONT_BASE=front-base@sha256:43457ed94fdde1f9fb14bf27b96b6ad6377796833516c5013f40fbbc8a9ff1c2
FROM ${FRONT_BASE}
USER root
WORKDIR /opt/magentic/front
COPY notes.html hooks.js notes.js src/overrides/
ENV FRONT_OVERRIDE=/opt/magentic/front/src/overrides
USER bun
EXPOSE 3000
CMD ["bun", "run", "src/server.js"]
