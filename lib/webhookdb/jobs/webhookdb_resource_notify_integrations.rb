# frozen_string_literal: true

require "webhookdb/async/job"
require "stripe"
require "webhookdb/stripe"

# All the 'webhookdb' integrations are internal, so this endpoint is not hardened thoroughly.
# If we were to open this up or use it on prod, we need to harden it to support
# more and slower endpoints (at least by fanning out the work).
class Webhookdb::Jobs::WebhookdbResourceNotifyIntegrations
  extend Webhookdb::Async::Job

  # As we add more resources, modify this wildcard
  on "webhookdb.customer.created"

  sidekiq_options queue: "netout"

  def _perform(event)
    cu = self.lookup_model(Webhookdb::Customer, event)
    Webhookdb::ServiceIntegration.where(service_name: "webhookdb_customer_v1").each do |sint|
      Webhookdb::Http.post(
        sint.replicator.webhook_endpoint,
        cu.values,
        headers: {"Whdb-Secret" => sint.webhook_secret},
        logger: self.logger,
        timeout: nil,
      )
    end
  end
end
