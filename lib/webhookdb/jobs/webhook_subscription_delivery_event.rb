# frozen_string_literal: true

require "amigo/queue_backoff_job"
require "amigo/durable_job"
require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent
  include Sidekiq::Worker
  include Amigo::DurableJob
  include Amigo::QueueBackoffJob

  sidekiq_options queue: "netout"

  def dependent_queues = ["critical"]

  def perform(delivery_id)
    delivery = Webhookdb::WebhookSubscription::Delivery[delivery_id]
    Webhookdb::Async::JobLogger.set_job_tags(
      webhook_subscription_delivery_id: delivery.id,
      webhook_subscription_id: delivery.webhook_subscription_id,
      organization: delivery.webhook_subscription.fetch_organization,
    )
    delivery.attempt_delivery
  end
end
