# frozen_string_literal: true

require "faker"
require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::Customers
  extend Webhookdb::Fixtures

  PASSWORD = "webhookdb1234"

  fixtured_class Webhookdb::Customer

  base :customer do
    self.name ||= Faker::Name.name
    self.email ||= Faker::Internet.email
    self.password_digest ||= Webhookdb::Customer::PLACEHOLDER_PASSWORD_DIGEST
  end

  before_saving do |instance|
    instance
  end

  decorator :password do |pwd=nil|
    pwd ||= PASSWORD
    self.password = pwd
  end

  decorator :plus_sign do |part=nil|
    part ||= SecureRandom.hex(8)
    local, domain = self.email.split("@")
    self.email = "#{local}+#{part}@#{domain}"
  end

  decorator :admin, presave: true do
    self.add_role(Webhookdb::Role.admin_role)
  end

  decorator :with_role, presave: true do |role|
    role ||= Faker::Lorem.word
    role = Webhookdb::Role.find_or_create(name: role) if role.is_a?(String)
    self.add_role(role)
  end

  decorator :with_email do |username=nil|
    self.email = (username || Faker::Internet.username) + "@example.com"
  end

  decorator :verified_in_org, presave: true do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    Webhookdb::Fixtures.organization_membership.verified.create(customer: self, organization: org)
  end

  decorator :admin_in_org, presave: true do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    Webhookdb::Fixtures.organization_membership.verified.admin.create(customer: self, organization: org)
  end

  decorator :invited_to_org, presave: true do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    Webhookdb::Fixtures.organization_membership.invite.create(customer: self, organization: org)
  end
end
