# rails-base: the PLATFORM base image. Not an app.
#
# magentic-stack builds this; consumers build a thin image FROM it and add their
# own code -- mind-pod's back, magentic-market-ai-site, and every user-generated
# Rails app. It therefore contains NO app code, no routes and no config: only a
# Ruby, the OS packages a stock Rails 8 app needs, and a populated GEM_HOME.
#
# Two properties this buys, both available against a tag (docs/plans/pod-to-vps.md):
#   source-code consistency  a layer never re-derives the bundle, gems or packages
#   behavioural consistency  every layer runs the SAME cpcp / Profile 9 / component
#                            runtime, because it is literally the same code
#
# Ruby is 3.4.9 because the platform must standardise on one -- a user app cannot
# choose. Pinned to the multi-arch index digest, so this resolves on arm64 and on
# the x86_64 VPS from the same reference.
FROM ruby:3.4.9-slim@sha256:c2637069aa39420c6f4f2638fc6c7dbcf35fc5a85263a0ef00d823f34e2a589e

# Stock Rails 8 runtime deps: sqlite3, libvips for Active Storage variants,
# jemalloc for Puma, curl for healthchecks. build-essential and git stay because
# a consuming layer may add a gem with a native extension -- this is a BUILD base,
# unlike the mind image, which is a runtime and was stripped to distroless.
RUN apt-get update -qq \
 && apt-get install --no-install-recommends -y \
      build-essential git curl libjemalloc2 libvips sqlite3 libsqlite3-dev libyaml-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Build the platform's own interfaces into real gems and install them into
# GEM_HOME. A consuming app then writes `gem "rails-cpcp"` -- no path, no git ref,
# no GitHub at build time. That last one matters: magentic-market-ai-site pulls
# rails-cpcp from a git ref today, so every build of it needs network + creds.
COPY interfaces/rails-cpcp        /opt/magentic/src/rails-cpcp
COPY interfaces/rails-osi-level-8 /opt/magentic/src/rails-osi-level-8
COPY interfaces/vv-html-components /opt/magentic/src/vv-html-components
COPY interfaces/mmg-semantic-editor  /opt/magentic/src/mmg-semantic-editor
RUN set -eux; \
    for g in rails-cpcp rails-osi-level-8 vv-html-components mmg-semantic-editor; do \
      cd "/opt/magentic/src/$g"; \
      gem build "$g.gemspec" -o "/tmp/$g.gem"; \
      gem install "/tmp/$g.gem" --no-document; \
    done; \
    rm -f /tmp/*.gem

# The component runtime at a stable path. rails-osi-level-8's rendered pages
# cannot hydrate without it, so every layer gets it whether or not it knows to ask.
RUN mkdir -p /opt/magentic/assets \
 && cp /opt/magentic/src/vv-html-components/dist/vv-html-components.js /opt/magentic/assets/ \
 && cp /opt/magentic/src/rails-osi-level-8/data/osi-level-8/ux-host-layout.js /opt/magentic/assets/

# Populate GEM_HOME from the platform Gemfile. The lock is generated HERE and
# kept, so what the base offers is a resolved set rather than a range -- a
# consuming app that matches it installs nothing.
WORKDIR /opt/magentic/platform
COPY runtimes/rails-base/Gemfile ./
RUN bundle install

# Where a consuming layer puts its app. Left empty on purpose: an image that
# ships app code is an application, not a base.
WORKDIR /rails
ENV RAILS_ENV=production \
    MAGENTIC_ASSETS=/opt/magentic/assets \
    LD_PRELOAD=libjemalloc.so.2
CMD ["irb"]
