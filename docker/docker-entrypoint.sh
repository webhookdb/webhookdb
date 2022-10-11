#!/bin/sh
set -e

if [ "$1" = "worker" ]; then
  bundle exec sidekiq -r ./config/sidekiq.rb -C ./config/sidekiq.yml
elif [ "$1" = "web" ]; then
  bundle exec puma -C config/puma.rb
elif [ "$1" = "release" ]; then
  bundle exec rake release
else
  exec "$@"
fi
