# The mind-pod app: ONE image, THREE roles (back / front / backjob) selected at
# runtime by $ROLE. Build once, run three ways -- this is the "extract" artifact.
FROM ruby:3.3-slim@sha256:649a5d3b7ca4f574a5f84a61bd79cdc7cca2bbd1f882fbe6c1eb4fdbc7454738
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-dev libyaml-dev git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# vendor/rails-cpcp and vendor/rails-osi-level-8 must be materialized (bin/prepare) before build.
# Install exactly what the COMMITTED lock names, with the bundler that wrote it.
# Copying Gemfile ALONE let `bundle install` resolve a different set, and the
# `COPY . .` below then overwrote the image's own lock with the host's -- so the
# image booted against a lock whose gems it had never installed (rbs-4.1.3 not
# found at runtime). The lock must be present BEFORE install, not after.
COPY Gemfile Gemfile.lock ./
COPY vendor/rails-cpcp ./vendor/rails-cpcp
COPY vendor/rails-osi-level-8 ./vendor/rails-osi-level-8
RUN gem install bundler -v "$(tail -n1 Gemfile.lock | tr -d '[:space:]')" \
    && bundle install
COPY . .
ENV RAILS_ENV=production
EXPOSE 3000
ENTRYPOINT ["extract/entrypoint.sh"]
