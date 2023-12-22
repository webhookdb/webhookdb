# frozen_string_literal: true

source "https://rubygems.org"
ruby "3.2.1"

gem "activesupport"
gem "appydays", "~> 0.7"
gem "aws-sdk-pricing"
gem "aws-sdk-sts"
gem "barnes"
gem "bcrypt"
gem "biz"
gem "concurrent-ruby"
gem "dotenv"
gem "down"
gem "foreman"
gem "grape", "=1.7.0"
gem "grape-entity"
gem "grape_logging"
gem "grape-swagger"
gem "httparty"
# Pull in BYPOS ICal rule fix from https://github.com/ice-cube-ruby/ice_cube/pull/449
gem "ice_cube", git: "https://github.com/nehresma/ice_cube.git", ref: "d7ea51efcd"
gem "liquid"
gem "mail"
gem "mimemagic"
gem "monetize"
gem "money"
gem "name_of_person"
gem "nokogiri", ">= 1.12" # Apple M1
gem "oj"
gem "pg"
gem "phony"
gem "platform-api"
gem "premailer"
gem "pry"
gem "puma"
gem "rack-cors"
gem "rack-protection"
gem "rack-ssl-enforcer"
gem "rake"
gem "redis"
gem "redis-client"
gem "semantic_logger"
gem "sentry-ruby"
gem "sentry-sidekiq"
gem "sequel"
gem "sequel-annotate"
gem "sequel-money-fields"
gem "sequel_pg"
gem "sequel_postgresql_triggers"
gem "sequel-soft-deletes"
gem "sequel-tstzrange-fields", ">= 0.2.1"
gem "sidekiq", "~> 6"
gem "sidekiq-amigo", ">= 1.6.0"
gem "sidekiq-cron"
gem "slack-notifier"
gem "stripe"
gem "warden"

# By default, Heroku ignores 'test' gem groups.
# But for ci, we need these gems loaded. It doesn't appear possible to 'fool' heroku using BUNDLE_WITHOUT
# to only exclude some fake group.
# So we include this test group by default, then BUNDLE_WITHOUT the real apps.
group :test_group do
  gem "amazing_print"
  gem "clipboard"
  gem "faker"
  gem "fluent_fixtures"
  gem "rack-test"
  gem "rspec", ">= 3.12.0"
  gem "rspec-eventually"
  gem "rspec-json_expectations"
  gem "rubocop"
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-sequel", require: false
  gem "timecop"
  gem "watir"
  gem "webmock"
end
