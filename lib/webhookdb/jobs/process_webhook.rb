# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::ProcessWebhook
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.webhook"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    self.with_log_tags(
      service_integration_id: sint.id,
      service_integration_name: sint.service_name,
      service_integration_table: sint.table_name,
    ) do
      kwargs = event.payload[1].symbolize_keys
      svc = Webhookdb::Services.service_instance(sint)
      svc.ensure_all_columns
      svc.upsert_webhook(body: kwargs.fetch(:body))
    end
  end
end
