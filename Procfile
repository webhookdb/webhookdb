web: bundle exec puma -C config/puma.rb
release: bash bin/release
worker: bundle exec sidekiq -r ./config/sidekiq.rb -C ./config/sidekiq.yml
