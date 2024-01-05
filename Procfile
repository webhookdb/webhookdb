web: bundle exec puma -C config/puma.rb
release: bundle exec rake release
worker: bundle exec sidekiq -r ./config/sidekiq.rb -C ./config/sidekiq.yml
