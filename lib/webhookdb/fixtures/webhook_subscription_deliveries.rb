# frozen_string_literal: true

require "webhookdb/fixtures"

module Webhookdb::Fixtures::WebhookSubscriptionDeliveries
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::WebhookSubscription::Delivery

  base :webhook_subscription_delivery do
    self.payload ||= {}
  end

  before_saving do |instance|
    instance.webhook_subscription ||= Webhookdb::Fixtures.webhook_subscription.create
    instance
  end
end
