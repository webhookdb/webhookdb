# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SendWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.rowupsert"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    # send out webhooks, if subscriptions are present
    sint.all_webhook_subs.each do |sub|
      sub.deliver(service_name: sint.service_name, table_name: sint.table_name, **event.payload[1].symbolize_keys)
    end
  end
end
