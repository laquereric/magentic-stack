# MIND: the Magentic cognition container. It HOSTS NVIDIA NOOA as-published
# (pinned, unmodified) and exposes only the harness seam to BACK. No UI (FRONT
# owns UI), no DB, no direct GRAPH. Run mind/bin/prepare first to vendor NOOA.
FROM python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a
# No build-essential: every native dependency (pydantic_core, litellm rust_bridge,
# markupsafe, rpds, frozenlist) resolves to a prebuilt aarch64 wheel, so the C
# toolchain was only ever attack surface in the container the pod trusts least.
WORKDIR /mind
# Install NOOA from the pinned immutable source (no floating PyPI latest).
ENV SETUPTOOLS_SCM_PRETEND_VERSION=0.0.9
COPY vendor/nooa /nooa-src
# Install, then drop the source in the SAME layer -- a later `rm` would leave it
# in the image anyway. MIND is the least-trusted container in the pod; it should
# carry what it runs and nothing it merely needed in order to be built.
RUN pip install --no-cache-dir /nooa-src && rm -rf /nooa-src
# Copy the two modules that actually run, not the whole context. `COPY . .` also
# landed vendor/nooa a SECOND time -- 56M of pip input duplicated into the runtime
# image. (Excluding vendor/ via .dockerignore is not the fix: that would also hide
# it from the COPY above, which needs it.) harness.py is stdlib-only; mind_agent.py
# needs pydantic, which NOOA already brings.
COPY harness.py mind_agent.py ./
ENV BACK_URL=http://back:3000 NOOA_COMMIT=8b3c719
CMD ["python", "harness.py"]
