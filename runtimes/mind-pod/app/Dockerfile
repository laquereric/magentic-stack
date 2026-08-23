# The mind-pod app: ONE image, THREE roles (back / front / backjob) selected at
# runtime by $ROLE. Build once, run three ways -- this is the "extract" artifact.
FROM ruby:3.3-slim@sha256:649a5d3b7ca4f574a5f84a61bd79cdc7cca2bbd1f882fbe6c1eb4fdbc7454738
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-dev libyaml-dev git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# vendor/rails-cpcp and vendor/rails-osi-level-8 must be materialized (bin/prepare) before build.
COPY Gemfile ./
COPY vendor/rails-cpcp ./vendor/rails-cpcp
COPY vendor/rails-osi-level-8 ./vendor/rails-osi-level-8
RUN bundle install
COPY . .
ENV RAILS_ENV=production
EXPOSE 3000
ENTRYPOINT ["extract/entrypoint.sh"]
