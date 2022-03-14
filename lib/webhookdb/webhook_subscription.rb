# frozen_string_literal: true

class Webhookdb::WebhookSubscription < Webhookdb::Postgres::Model(:webhook_subscriptions)
  plugin :timestamps
  plugin :column_encryption do |enc|
    enc.column :webhook_secret
  end

  many_to_one :service_integration, class: Webhookdb::ServiceIntegration
  many_to_one :organization, class: Webhookdb::Organization
  many_to_one :created_by, class: Webhookdb::Customer

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

  def associated_type
    return "organization" unless self.organization_id.nil?
    return "service_integration" unless self.service_integration_id.nil?
    return ""
  end

  def associated_id
    return self.organization.key unless self.organization_id.nil?
    return self.service_integration.opaque_id unless self.service_integration_id.nil?
    return ""
  end
end
