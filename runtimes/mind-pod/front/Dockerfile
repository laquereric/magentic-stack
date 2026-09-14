# mind-pod FRONT: thin overlay on front-base. Core is the homepage.
# Notes nest at /notes. Same skeleton digest as sharedai.space.
ARG FRONT_BASE=front-base@sha256:43f1b1f3dda7af90ce7cf9e4915d82a4b5cf843e98d07cf6e59dd8763e741a65
FROM ${FRONT_BASE}
USER root
WORKDIR /opt/magentic/front
COPY notes.html hooks.js notes.js src/overrides/
ENV FRONT_OVERRIDE=/opt/magentic/front/src/overrides
USER bun
EXPOSE 3000
CMD ["bun", "run", "src/server.js"]
