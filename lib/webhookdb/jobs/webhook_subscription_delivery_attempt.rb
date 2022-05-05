# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent
  include Sidekiq::Worker

  sidekiq_options queue: "netout"

  def perform(delivery_id)
    delivery = Webhookdb::WebhookSubscription::Delivery[delivery_id]
    Webhookdb::Async::JobLogger.with_log_tags(
      webhook_subscription_delivery_id: delivery.id,
      webhook_subscription_id: delivery.webhook_subscription_id,
      organization_key: delivery.webhook_subscription.fetch_organization,
    ) do
      delivery.attempt_delivery
    end
  end
end
