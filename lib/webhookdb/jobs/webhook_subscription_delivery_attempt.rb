# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent
  include Sidekiq::Worker

  def perform(delivery_id)
    delivery = Webhookdb::WebhookSubscription::Delivery[delivery_id]
    delivery.attempt_delivery
  end
end
