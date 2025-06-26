# frozen_string_literal: true

source "https://rubygems.org"
ruby "3.4.4"

gemspec

# Pull in BYPOS ICal rule fix from https://github.com/ice-cube-ruby/ice_cube/pull/449
gem "ice_cube", git: "https://github.com/nehresma/ice_cube.git", ref: "d7ea51efcd"

# NOTE: When running integration tests, you will need to set BUNDLE_WITHOUT to something other than 'test'.
group :test do
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

group :enterprise do
  ENV.fetch("WEBHOOKDB_ENTERPRISE_BUNDLE", nil) &&
    gem("webhookdb-enterprise", git: "https://github.com/webhookdb/webhookdb-enterprise.git", ref: "main")
end
