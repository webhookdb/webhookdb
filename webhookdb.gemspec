# frozen_string_literal: true

require_relative "lib/webhookdb/version"

Gem::Specification.new do |s|
  s.name = "webhookdb"
  s.version = Webhookdb::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = "Replicate any API to your database with WebhookDB."
  s.author = "WebhookDB"
  s.homepage = "https://github.com/webhookdb/webhookdb"
  s.licenses = "Apache 2.0"
  s.required_ruby_version = ">= 3.2.0"
  s.metadata["rubygems_mfa_required"] = "true"
  s.description = <<~DESC
    Replicate any API to your database with WebhookDB.

    WebhookDB handles webhooks and intelligently polls APIs to provide
    a normalized, schematized, relational copy of API data.

    No new APIs to learn -- just an easy-to-use CLI to set up integrations,
    and then you get a database connection string to access your data.
    WebhookDB keeps everything up to date, automatically.

    Explore the extensive documentation at https://docs.webhookdb.com.
  DESC

  s.files = Dir["lib/**/*.rb"]
  s.files += Dir["data/**/*"]
  s.files += Dir["db/**/*.rb"]

  s.add_dependency("activesupport", "~> 7.1")
  s.add_dependency("appydays", ">= 0.8")
  s.add_dependency("aws-sdk-pricing", "~> 1.53")
  s.add_dependency("aws-sdk-sts", "~> 1.11")
  s.add_dependency("barnes", "~> 0.0")
  s.add_dependency("bcrypt", "~> 3.1")
  s.add_dependency("biz", "~> 1.8")
  s.add_dependency("concurrent-ruby", "~> 1.2")
  s.add_dependency("down", "~> 5.4")
  s.add_dependency("foreman", "~> 0.87")
  s.add_dependency("grape", "~> 2.0.0")
  s.add_dependency("grape-entity", "~> 1.0.0")
  s.add_dependency("grape_logging", "~> 1.8.4")
  s.add_dependency("grape-swagger", "~> 2.0.0")
  s.add_dependency("httparty", "~> 0.21")
  s.add_dependency("ice_cube")
  s.add_dependency("liquid", "~> 5.4")
  s.add_dependency("mail", "~> 2.8")
  s.add_dependency("mimemagic", "~> 0.4")
  s.add_dependency("monetize", "~> 1.12")
  s.add_dependency("money", "~> 6.16")
  s.add_dependency("nokogiri", "~> 1.16") # >= 1.16 Apple M1
  s.add_dependency("oj", "~> 3.16")
  s.add_dependency("pg", "~> 1.5")
  s.add_dependency("phony", "~> 2.20")
  s.add_dependency("platform-api", "~> 3.5")
  s.add_dependency("premailer", "~> 1.21")
  s.add_dependency("pry", "~> 0.14")
  s.add_dependency("puma", "~> 6.4")
  s.add_dependency("rack-cors", "~> 2.0")
  s.add_dependency("rack-protection", "~> 3.2")
  s.add_dependency("rack-ssl-enforcer", "~> 0.2")
  s.add_dependency("rake", "~> 13.1")
  s.add_dependency("redis", "~> 4.8")
  s.add_dependency("redis-client", "~> 0.19")
  s.add_dependency("semantic_logger", "~> 4.15")
  s.add_dependency("sentry-ruby", "~> 5.15")
  s.add_dependency("sentry-sidekiq", "~> 5.15")
  s.add_dependency("sequel", "~> 5.75")
  s.add_dependency("sequel-annotate", "~> 1.7")
  s.add_dependency("sequel-money-fields", "~> 0.1")
  s.add_dependency("sequel_pg", "~> 1.17")
  s.add_dependency("sequel_postgresql_triggers", "~> 1.5")
  s.add_dependency("sequel-soft-deletes", "~> 0.1")
  s.add_dependency("sequel-tstzrange-fields", "~> 0.2")
  s.add_dependency("sidekiq", "~> 6")
  s.add_dependency("sidekiq-amigo", "~> 1.6")
  s.add_dependency("sidekiq-cron", "~> 1.12")
  s.add_dependency("slack-notifier", "~> 2.4")
  s.add_dependency("stripe", "~> 10.4")
  s.add_dependency("warden", "~> 1.2")
end
