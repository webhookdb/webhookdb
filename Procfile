web: bundle exec puma -C config/puma.rb
release: bash bin/release
worker: bundle exec sidekiq -c 4 -t 25 -r ./config/sidekiq.rb
