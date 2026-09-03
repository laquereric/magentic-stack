# MIND: the Magentic cognition container. It HOSTS NVIDIA NOOA as-published
# (pinned, unmodified) and exposes only the harness seam to BACK. No UI (FRONT
# owns UI), no DB, no direct GRAPH. Run mind/bin/prepare first to vendor NOOA.
#
# DISTROLESS. MIND runs the upstream agent and is the container this pod trusts
# least, so the runtime stage carries a Python interpreter and nothing else: no
# shell, no apt/dpkg, no package manager, no compiler. Code execution here has
# no /bin/sh to reach for. The /_cpcp seam was always what gated BACK; this is
# about how much is reachable inside the box we already chose not to trust.
#
# The interpreter version is set BY the runtime image, not by us: distroless
# python3-debian13 ships 3.13. The builder must match it exactly or the cp313
# wheels (pydantic_core, litellm rust_bridge, markupsafe, rpds, frozenlist) will
# not import. Bump both stages together, never one.
#
# debian12 is NOT usable here: it ships Python 3.11 and NOOA requires >=3.12,<3.14.
# That constraint is what picks the base -- not a preference for trixie.
FROM python:3.13-slim@sha256:ffb752e139c0a19692a43af8d8523b274222dd68eebad5d583b45c2201c6e30a AS builder
ENV SETUPTOOLS_SCM_PRETEND_VERSION=0.0.9
# Install NOOA from the pinned immutable source (no floating PyPI latest).
# --target keeps the whole dependency tree in one directory we can lift out.
COPY vendor/nooa /nooa-src
RUN pip install --no-cache-dir --target=/deps /nooa-src

FROM gcr.io/distroless/python3-debian13@sha256:84e04b1c8a7904c81563ea125db995ba321fd330f3731f0a841e2f90757c4667
WORKDIR /mind
# Only the installed tree crosses the stage boundary. /nooa-src, pip, setuptools
# and the build toolchain stay in the builder and never reach the runtime image.
COPY --from=builder /deps /deps
# harness.py is stdlib-only; mind_agent.py needs pydantic, which NOOA brings.
# mind_seam.py is stdlib-only (http.server): the row-10 seam, served on a
# daemon thread by harness.main. Pod-internal, never published (no ports:).
COPY harness.py mind_agent.py mind_seam.py ./
EXPOSE 8091
ENV PYTHONPATH=/deps BACK_URL=http://back:3000 NOOA_COMMIT=8b3c719
# ENTRYPOINT is the image's own /usr/bin/python3.13 -- CMD supplies the script.
CMD ["harness.py"]
