# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SendTestWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.webhooksubscription.test"
  sidekiq_options queue: "netout"

  # If this job fails for a programmer error,
  # we don't want to retry and randomly send a payload later.
  sidekiq_options retry: false

  def _perform(event)
    webhook_sub = self.lookup_model(Webhookdb::WebhookSubscription, event)
    webhook_sub.deliver_test_event
  end
end
