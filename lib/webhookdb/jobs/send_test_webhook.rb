# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::SendTestWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.webhooksubscription.test"

  def _perform(event)
    webhook_sub = self.lookup_model(Webhookdb::WebhookSubscription, event)
    webhook_sub.deliver(
      service_name: "test service",
      table_name: "test_table_name",
      external_id: SecureRandom.hex(6),
      external_id_column: "external_id",
      row: {data: ["alpha", "beta", "charlie", "delta"]},
    )
  end
end
