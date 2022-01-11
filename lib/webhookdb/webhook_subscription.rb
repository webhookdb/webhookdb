# frozen_string_literal: true

class Webhookdb::WebhookSubscription < Webhookdb::Postgres::Model(:webhook_subscriptions)
  many_to_one :service_integration, class: Webhookdb::ServiceIntegration
  many_to_one :organization, class: Webhookdb::Organization
  plugin :column_encryption do |enc|
    enc.column :webhook_secret
  end

  def deliver(service_name:, table_name:, row:, external_id:, external_id_column:)
    body = {
      service_name:,
      table_name:,
      row:,
      external_id:,
      external_id_column:,
    }
    Webhookdb::Http.post(
      self.deliver_to_url,
      body:,
      headers: {
        "Webhookdb-Webhook-Secret" => self.webhook_secret,
      },
      logger: self.logger,
    )
  end
end
