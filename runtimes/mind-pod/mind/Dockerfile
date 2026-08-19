# MIND: the Magentic cognition container. It HOSTS NVIDIA NOOA as-published
# (pinned, unmodified) and exposes only the harness seam to BACK. No UI (FRONT
# owns UI), no DB, no direct GRAPH. Run mind/bin/prepare first to vendor NOOA.
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /mind
# Install NOOA from the pinned immutable source (no floating PyPI latest).
ENV SETUPTOOLS_SCM_PRETEND_VERSION=0.0.9
COPY vendor/nooa /nooa-src
RUN pip install --no-cache-dir /nooa-src
COPY . .
ENV BACK_URL=http://back:3000 NOOA_COMMIT=8b3c719
CMD ["python", "harness.py"]
