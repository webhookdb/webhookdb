# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/processor"

class Webhookdb::Async::ProcessWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.webhook"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    kwargs = event.payload[1].symbolize_keys
    Webhookdb::Processor.process(sint, **kwargs)
  end
end
