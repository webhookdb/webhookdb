# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::WebhookSubscriptions
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::WebhookSubscription

  base :webhook_subscription do
    self.opaque_id ||= SecureRandom.hex(8)
    self.webhook_secret ||= "wh_secret_" + SecureRandom.hex(2)
    self.deliver_to_url ||= Faker::Internet.url
  end

  before_saving do |instance|
    unless instance.organization.present?
      instance.service_integration ||= Webhookdb::Fixtures.service_integration.create
    end
    instance
  end

  decorator :for_org do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    self.service_integration = nil
    self.organization = org
  end
end
