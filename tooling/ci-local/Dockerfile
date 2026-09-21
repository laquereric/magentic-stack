# The runner, locally. Built to be BORING and to match gate-main-green's
# environment rather than a developer's.
#
# WHY THIS EXISTS. Every failure in the 2026-09-20 main-green campaign was a
# difference between a laptop and the runner, and none of them could be
# reproduced locally:
#
#   a sqlite the gate measured was gitignored, so it existed only on one machine
#   an artifact carried '/Users/<someone>/...' baked in by a generator
#   four per-gem bundles the checkers shell into were never installed on CI
#   the venv CI built held half of what the sweep needs
#   a generator was looked up under ROOT/.venv/bin, which CI did not have
#
# Each was found by pushing and reading a log. This image is the shorter loop:
# Linux, a CLEAN checkout, and the same steps the workflow runs.
#
# VERSIONS ARE THE POINT, so both are pinned to what the workflow asks for --
# python 3.12 (setup-python) and ruby 3.3 (setup-ruby). Neither base carries
# both: ubuntu:24.04 has python3.12 but only ruby3.2, and ruby:3.3-slim is
# bookworm, whose python is 3.11. They are both Debian bookworm, so the python
# runtime is lifted from the official image rather than built or approximated.
FROM python:3.12-slim-bookworm@sha256:392307d22300de8b5986851a12d9176dfc0fc073e65bf6523ebd7dcbeb23564e AS py

FROM ruby:3.3-slim-bookworm@sha256:eff17a5c68e1426bfe1b2bb3927f6f3cd731354f876713cb85aea243b24db8a0

# Copy ONLY python's own files. /usr/local is where both images install, so a
# blanket copy would overwrite the ruby this image exists to provide.
COPY --from=py /usr/local/bin/python3.12 /usr/local/bin/python3.12
COPY --from=py /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=py /usr/local/lib/libpython3.12.so.1.0 /usr/local/lib/
COPY --from=py /usr/local/include/python3.12 /usr/local/include/python3.12

RUN set -eux; \
    ldconfig; \
    ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3; \
    ln -sf /usr/local/bin/python3.12 /usr/local/bin/python; \
    python3 -m ensurepip --upgrade; \
    ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip3 || true

# git: the gate clones the tree and inits submodules, as checkout@v4 does.
# build-essential/pkg-config/libyaml/libsqlite3: native gems (psych, sqlite3).
# sqlite3: plant_two_writers measures a real database.
# ca-certificates: rubygems and pypi over TLS.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git build-essential pkg-config ca-certificates \
      libyaml-dev libsqlite3-dev sqlite3 libffi-dev zlib1g-dev locales; \
    rm -rf /var/lib/apt/lists/*

# GENERATE the locale, do not just name it. gate-main-green sets
# LANG=en_US.UTF-8, and a slim Debian has no such locale compiled -- so every
# shell opened with "setlocale: LC_ALL: cannot change locale (en_US.UTF-8)"
# and fell back to C. The sweep calls ensure_lang() and would have papered
# over it, which is exactly the kind of quiet divergence this image exists to
# remove: it must fail or match, not approximate.
RUN set -eux; \
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    locale -a | grep -qi 'en_US.utf8'

# The sweep refuses a non-UTF-8 LANG, and gate-main-green sets this explicitly.
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    BUNDLE_JOBS=4

WORKDIR /work
CMD ["/bin/bash"]
