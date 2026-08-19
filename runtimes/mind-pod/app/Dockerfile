# The mind-pod app: ONE image, THREE roles (back / front / backjob) selected at
# runtime by $ROLE. Build once, run three ways -- this is the "extract" artifact.
FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-dev libyaml-dev git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# vendor/rails-cpcp must be materialized (bin/prepare) before build.
COPY Gemfile ./
COPY vendor/rails-cpcp ./vendor/rails-cpcp
RUN bundle install
COPY . .
ENV RAILS_ENV=production
EXPOSE 3000
ENTRYPOINT ["extract/entrypoint.sh"]
