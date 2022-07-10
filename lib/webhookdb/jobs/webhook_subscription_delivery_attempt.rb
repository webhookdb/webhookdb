# frozen_string_literal: true

require "amigo/backoff_job"
require "amigo/durable_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent
  include Sidekiq::Worker
  include Amigo::DurableJob
  include Amigo::BackoffJob

  sidekiq_options queue: "netout"

  def dependent_queues
    return ["critical"]
  end

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
