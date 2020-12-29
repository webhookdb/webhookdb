# frozen_string_literal: true

source "https://rubygems.org"
ruby "2.7.2"

gem "activesupport"
gem "aws-sdk-s3"
gem "bcrypt"
gem "biz"
gem "dotenv"
gem "foreman"
gem "grape"
gem "grape-entity"
gem "grape_logging"
gem "grape-swagger"
gem "httparty"
gem "liquid"
gem "mimemagic"
gem "monetize"
gem "money"
gem "name_of_person"
gem "nokogiri"
gem "pg"
gem "phony"
gem "platform-api"
gem "postmark"
gem "premailer"
gem "pry"
gem "puma"
gem "rack-cors"
gem "rack-protection"
gem "rack-ssl-enforcer"
gem "rake"
gem "semantic_logger"
gem "sentry-raven"
gem "sequel"
gem "sequel-annotate"
gem "sequel_pg"
gem "sequel_postgresql_triggers"
gem "sidekiq"
gem "sidekiq-cron"
gem "slack-notifier"
gem "twilio-ruby"
gem "warden"
gem "yajl-ruby"

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
  gem "rspec"
  gem "rspec-eventually"
  gem "rspec-json_expectations"
  gem "rubocop"
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-sequel", require: false
  gem "timecop"
  gem "watir"
  gem "webmock"
end
