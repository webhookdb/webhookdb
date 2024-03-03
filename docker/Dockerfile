FROM ruby:3.2.1-slim

RUN apt-get update && apt-get install -y build-essential shared-mime-info libpq-dev git


WORKDIR /app
COPY Gemfile* .
COPY webhookdb.gemspec .
COPY lib/webhookdb/version.rb lib/webhookdb/version.rb
RUN bundle install --deployment
COPY ./admin-dist admin-dist
COPY ./config config
COPY ./data data
COPY ./db db
COPY ./integration integration
COPY ./lib lib
COPY ./.env .env
COPY ./.pryrc .pryrc
COPY ./config.ru config.ru
COPY ./Procfile Procfile
COPY ./Rakefile Rakefile
COPY ./docker/docker-entrypoint.sh /docker-entrypoint.sh

ARG GIT_SHA
ARG GIT_REF
ARG BUILT_AT
ENV GIT_SHA=$GIT_SHA
ENV GIT_REF=$GIT_REF
ENV BUILT_AT=$BUILT_AT

EXPOSE $PORT
ENTRYPOINT ["/docker-entrypoint.sh"]
