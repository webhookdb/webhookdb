# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::Organizations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Organization

  base :organization do
    self.name ||= Faker::Company.name + SecureRandom.hex(2)
    self.stripe_customer_id = "cus_" + SecureRandom.hex(8)
  end

  decorator :with_member, presave: true do |c={}|
    c = Webhookdb::Fixtures.customer.create(c) unless c.is_a?(Webhookdb::Customer)
    Webhookdb::Fixtures.organization_membership.verified.create(customer: c, organization: self)
  end

  decorator :with_invite, presave: true do |c={}|
    c = Webhookdb::Fixtures.customer.create(c) unless c.is_a?(Webhookdb::Customer)
    Webhookdb::Fixtures.organization_membership.invite.create(customer: c, organization: self)
  end

  decorator :with_urls do |admin: nil, readonly: nil|
    self.admin_connection_url_raw ||= admin || Faker::Webhookdb.pg_connection
    self.readonly_connection_url_raw ||= readonly || Faker::Webhookdb.pg_connection
  end
end
