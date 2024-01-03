FROM ruby:3.2.1-slim

RUN apt-get update && apt-get install -y build-essential shared-mime-info libpq-dev git

WORKDIR /app
COPY Gemfile* .
RUN bundle install
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

EXPOSE $PORT
ENTRYPOINT ["/docker-entrypoint.sh"]
