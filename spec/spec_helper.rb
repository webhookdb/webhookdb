# frozen_string_literal: true

# See https://github.com/eliotsykes/rspec-rails-examples/blob/master/spec/spec_helper.rb
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
#
require "appydays/dotenviable"
Appydays::Dotenviable.load(default_rack_env: "test")

require "simplecov"
require "simplecov-cobertura"

(SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter) if ENV["CI"]
SimpleCov.start if ENV["CI"] || ENV["COVERAGE"]

require "httparty"
require "rack/test"
require "rack/test/methods"
require "rspec"
require "rspec/json_expectations"
require "timecop"
require "webmock/rspec"
require "appydays/spec_helpers"
require "appydays/configurable/spec_helpers"
require "appydays/loggable/spec_helpers"

require "webhookdb"
require "webhookdb/spec_helpers"
require "webhookdb/spec_helpers/postgres"
require "webhookdb/fixtures"

Webhookdb.load_app
Webhookdb::Fixtures.load_all

RSpec.configure do |config|
  # config.full_backtrace = true

  RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 600

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  Kernel.srand config.seed

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?

  config.include(Appydays::SpecHelpers)
  config.include(Appydays::Configurable::SpecHelpers)
  config.include(Appydays::Loggable::SpecHelpers)

  # Several of these files have side effects of being loaded (like async loading sidekiq/testing),
  # and some just import files we don't care about having loaded.
  # Though some of the other spec helpers are needed for integration and webdriver testing,
  # and are imported at the top of the file.
  if Webhookdb::INTEGRATION_TESTS_ENABLED
    require "webhookdb/spec_helpers/integration"
    config.include(Webhookdb::IntegrationSpecHelpers)
  else
    require "amigo/spec_helpers"
    config.include(Amigo::SpecHelpers)

    config.include(Webhookdb::SpecHelpers)
    require "webhookdb/spec_helpers/async"
    config.include(Webhookdb::SpecHelpers::Async)
    require "webhookdb/spec_helpers/message"
    config.include(Webhookdb::SpecHelpers::Message)
    config.include(Webhookdb::SpecHelpers::Postgres)
    require "webhookdb/spec_helpers/service"
    config.include(Webhookdb::SpecHelpers::Service)
    require "webhookdb/spec_helpers/whdb"
    config.include(Webhookdb::SpecHelpers::Whdb)
  end
end
