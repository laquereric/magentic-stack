FROM ruby:3.3-slim
WORKDIR /app
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
COPY Gemfile ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-p", "3000", "-w", "0"]
