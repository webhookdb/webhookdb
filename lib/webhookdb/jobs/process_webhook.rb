# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Async::ProcessWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.webhook"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    kwargs = event.payload[1].symbolize_keys
    svc = Webhookdb::Services.service_instance(sint)
    svc.upsert_webhook(body: kwargs.fetch(:body))
  end
end
