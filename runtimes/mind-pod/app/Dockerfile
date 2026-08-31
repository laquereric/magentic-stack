# The mind-pod app: ONE image, roles (back / front / backjob / vault) selected at
# runtime by $ROLE. Build once, run several ways -- this is the "extract" artifact.
#
# THIN LAYER. This is the platform base configured to run as BACK, with rails-cpcp
# defining the front/back contract. It adds app code and nothing else: no Ruby, no
# OS packages, no gem tree, no vendoring step. Everything underneath comes from
# rails-base, which is also what magentic-market-ai-site and every user-generated
# Rails app build on. mind-pod is the FIRST consumer of that base, not an
# exception to it -- if the split does not work here it will not work for them.
#
# The base tag, not a digest: a local image id is reassigned on every build, so it
# names nothing durable. See docs/plans/pod-to-vps.md -- artifact identity is a
# separate problem from source-code and behavioural consistency, and only the
# former needs a digest.
ARG BASE=mind-pod-rails-base:latest
FROM ${BASE}

WORKDIR /rails

# rails-cpcp and rails-osi-level-8 are already installed in the base's GEM_HOME,
# so this resolves them without a path:, a git: ref, or GitHub. Only the app's own
# test gems are actually fetched -- the cost of leaving the platform set, which is
# the rule working, not a surprise.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# .dockerignore excludes db/*.sqlite3 — COPY . . does not read .gitignore.
COPY . .
ENV RAILS_ENV=production
EXPOSE 3000
ENTRYPOINT ["extract/entrypoint.sh"]
