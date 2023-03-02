# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::SendWebhook
  extend Webhookdb::Async::Job
  include Amigo::DurableJob

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    self.with_log_tags(sint.log_tags) do
      sint.all_webhook_subscriptions_dataset.to_notify.each do |sub|
        payload = {service_name: sint.service_name, table_name: sint.table_name, **event.payload[1]}
        sub.enqueue_delivery(payload)
      end
    end
  end
end
