# frozen_string_literal: true

source "https://rubygems.org"
ruby "3.2.1"

gem "activesupport", "~> 7.1"
gem "appydays", ">= 0.8"
gem "aws-sdk-pricing", "~> 1.53"
gem "aws-sdk-sts", "~> 1.11"
gem "barnes", "~> 0.0"
gem "bcrypt", "~> 3.1"
gem "biz", "~> 1.8"
gem "concurrent-ruby", "~> 1.2"
gem "down", "~> 5.4"
gem "foreman", "~> 0.87"
gem "grape", "~> 2.0.0"
gem "grape-entity", "~> 1.0.0"
gem "grape_logging", "~> 1.8.4"
gem "grape-swagger", "~> 2.0.0"
gem "httparty", "~> 0.21"
# Pull in BYPOS ICal rule fix from https://github.com/ice-cube-ruby/ice_cube/pull/449
gem "ice_cube", git: "https://github.com/nehresma/ice_cube.git", ref: "d7ea51efcd"
gem "liquid", "~> 5.4"
gem "mail", "~> 2.8"
gem "mimemagic", "~> 0.4"
gem "monetize", "~> 1.12"
gem "money", "~> 6.16"
gem "nokogiri", "~> 1.16" # Apple M1
gem "oj", "~> 3.16"
gem "pg", "~> 1.5"
gem "phony", "~> 2.20"
gem "platform-api", "~> 3.5"
gem "premailer", "~> 1.21"
gem "pry", "~> 0.14"
gem "puma", "~> 6.4"
gem "rack-cors", "~> 2.0"
gem "rack-protection", "~> 3.2"
gem "rack-ssl-enforcer", "~> 0.2"
gem "rake", "~> 13.1"
gem "redis", "~> 4.8"
gem "redis-client", "~> 0.19"
gem "semantic_logger", "~> 4.15"
gem "sentry-ruby", "~> 5.15"
gem "sentry-sidekiq", "~> 5.15"
gem "sequel", "~> 5.75"
gem "sequel-annotate", "~> 1.7"
gem "sequel-money-fields", "~> 0.1"
gem "sequel_pg", "~> 1.17"
gem "sequel_postgresql_triggers", "~> 1.5"
gem "sequel-soft-deletes", "~> 0.1"
gem "sequel-tstzrange-fields", "~> 0.2"
gem "sidekiq", "~> 6"
gem "sidekiq-amigo", "~> 1.6"
gem "sidekiq-cron", "~> 1.12"
gem "slack-notifier", "~> 2.4"
gem "stripe", "~> 10.4"
gem "warden", "~> 1.2"

# By default, Heroku ignores 'test' gem groups.
# But for ci, we need these gems loaded. It doesn't appear possible to 'fool' heroku using BUNDLE_WITHOUT
# to only exclude some fake group.
# So we include this test group by default, then BUNDLE_WITHOUT the real apps.
group :test_group do
  gem "amazing_print", "~> 1.5"
  gem "clipboard", "~> 1.3"
  gem "faker", "~> 3.2"
  gem "fluent_fixtures", "~> 0.11"
  gem "rack-test", "~> 2.1"
  gem "rspec", "~> 3.12"
  gem "rspec-eventually", "~> 0.2"
  gem "rspec-json_expectations", "~> 2.2"
  gem "rubocop", "~> 1.59"
  gem "rubocop-performance", "~> 1.20", require: false
  gem "rubocop-rake", "~> 0.6", require: false
  gem "rubocop-rspec", "~> 2.25", require: false
  gem "rubocop-sequel", "~> 0.3", require: false
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-cobertura", "~> 2.1"
  gem "timecop", "~> 0.9"
  gem "webmock", "~> 3.19"
end
