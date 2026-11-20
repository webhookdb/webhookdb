# frozen_string_literal: true

require "webhookdb/spec_helpers"
require "webhookdb/sentry"

module Webhookdb::SpecHelpers::Sentry
  def self.included(context)
    context.before(:each) do |example|
      if example.metadata[:sentry]
        # We need to fake doing what Sentry would be doing for initialization,
        # so we can assert it has the right data in its scope.
        Webhookdb::Sentry.dsn = "https://public:secret@test-sentry.webhookdb.com/whdb"
        hub = Sentry::Hub.new(
          Sentry::Client.new(Sentry::Configuration.new),
          Sentry::Scope.new,
        )
        expect(Sentry).to_not be_initialized
        Sentry.instance_variable_set(:@main_hub, hub)
        expect(Sentry).to be_initialized
      end
    end

    context.after(:each) do |example|
      if example.metadata[:sentry]
        Webhookdb::Sentry.reset_configuration
        expect(Sentry).to_not be_initialized
      end
    end

    super
  end
end
