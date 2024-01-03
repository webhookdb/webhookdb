#!/bin/sh
set -e

if [ "$1" = "worker" ]; then
  exec bundle exec sidekiq -r ./config/sidekiq.rb -C ./config/sidekiq.yml
elif [ "$1" = "web" ]; then
  exec bundle exec puma -C config/puma.rb
elif [ "$1" = "release" ]; then
  exec bundle exec rake release
else
  exec "$@"
fi
