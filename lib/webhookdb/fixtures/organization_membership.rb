# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::OrganizationMembership
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::OrganizationMembership

  base :organization_membership do
  end

  before_saving do |instance|
    raise "Must call :invite or :verified" if instance.verified.nil?
    instance.customer ||= Webhookdb::Fixtures.customer.create
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance.membership_role ||= Webhookdb::Role.non_admin_role
    instance
  end

  decorator :org do |o={}|
    o = Webhookdb::Fixtures.organization(o).create unless o.is_a?(Webhookdb::Organization)
    self.organization = o
  end

  decorator :customer do |c={}|
    c = Webhookdb::Fixtures.customer(c).create unless c.is_a?(Webhookdb::Customer)
    self.customer = c
  end

  decorator :invite do
    self.invitation_code ||= "code-" + SecureRandom.hex(4)
    self.verified = false
  end

  decorator :verified do
    self.verified = true
  end

  decorator :admin do
    self.membership_role = Webhookdb::Role.admin_role
  end

  decorator :default do
    self.is_default = true
  end

  decorator :code do |c|
    self.invitation_code = c
  end
end
