# frozen_string_literal: true

require "faker"
require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::Subscriptions
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Subscription

  base :subscription do
    self.stripe_id = "sub_" + SecureRandom.hex(8)
    self.stripe_customer_id = "cus_" + SecureRandom.hex(8)
  end

  decorator :active do
    self.stripe_json = "{\"status\": \"active\"}"
  end

  decorator :canceled do
    self.stripe_json = "{\"status\": \"canceled\"}"
  end

  decorator :for_org, presave: true do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    self.stripe_customer_id = org.stripe_customer_id
  end
end
