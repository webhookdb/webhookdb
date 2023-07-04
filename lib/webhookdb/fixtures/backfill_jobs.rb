# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::BackfillJobs
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::BackfillJob

  base :backfill_job do
    self.incremental = false if self.incremental.nil?
  end

  before_saving do |instance|
    instance.service_integration ||= Webhookdb::Fixtures.service_integration.create
    instance
  end

  after_saving do |instance|
    instance.setup_recursive if instance._fixture_cascade
    instance
  end

  decorator :for do |sint={}|
    sint = Webhookdb::Fixtures.service_integration.create(sint) unless sint.is_a?(Webhookdb::ServiceIntegration)
    self.service_integration = sint
  end

  decorator :cascade do |v=true|
    self._fixture_cascade = v
  end

  decorator :incremental do |v=true|
    self.incremental = v
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
