FROM ruby:3.2.1-slim

RUN apt-get update && apt-get install -y build-essential shared-mime-info libpq-dev git

WORKDIR /app
COPY .ruby-version .
COPY .ruby-gemset .
COPY Gemfile .
COPY Gemfile.lock .
COPY webhookdb.gemspec .
COPY lib/webhookdb/version.rb lib/webhookdb/version.rb
RUN bundle install
COPY ./docker/docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE $PORT
ENV DOCKER_DEV=true
ENTRYPOINT ["/docker-entrypoint.sh"]
