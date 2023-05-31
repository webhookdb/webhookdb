# frozen_string_literal: true

require "sidekiq/testing"

require "webhookdb/async"
require "webhookdb/slack"
require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Async
  def self.included(context)
    Sidekiq::Testing.inline!
    Amigo::QueueBackoffJob.reset

    context.before(:each) do |example|
      Sidekiq::Testing.inline!
      Webhookdb::Postgres.do_not_defer_events = true if example.metadata[:do_not_defer_events]
      if example.metadata[:slack]
        Webhookdb::Slack.http_client = Webhookdb::Slack::NoOpHttpClient.new
        Webhookdb::Slack.suppress_all = false
      end
      if example.metadata[:sentry]
        Webhookdb::Sentry.dsn = "http://public:secret@not-really-sentry.nope/someproject"
        Webhookdb::Sentry.run_after_configured_hooks
      end
    end

    context.after(:each) do |example|
      Webhookdb::Postgres.do_not_defer_events = false if example.metadata[:do_not_defer_events]
      if example.metadata[:slack]
        Webhookdb::Slack.http_client = nil
        Webhookdb::Slack.reset_configuration
      end
      Webhookdb::Sentry.reset_configuration if example.metadata[:sentry]
    end
    super
  end
end
