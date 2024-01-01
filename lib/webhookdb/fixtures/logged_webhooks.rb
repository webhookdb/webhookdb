# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::LoggedWebhooks
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::LoggedWebhook

  base :logged_webhook do
    self.request_body ||= "{}"
    self.request_headers ||= {}
    self.request_method ||= "POST"
    self.response_status ||= 0
    self.service_integration_opaque_id ||= SecureRandom.hex(2)
  end

  before_saving do |instance|
    instance.request_path ||= "/v1/service_integrations/#{instance.service_integration_opaque_id}"
    instance
  end

  decorator :ancient do
    self.inserted_at = Faker::Number.between(from: 200, to: 300).days.ago
  end

  decorator :success do
    self.response_status = 202
  end

  decorator :failure do
    self.response_status = rand(400..599)
  end

  decorator :with_organization do |org={}|
    org = Webhookdb::Fixtures.organization.create(org) unless org.is_a?(Webhookdb::Organization)
    self.organization = org
  end

  decorator :for_service_integration do |sint={}|
    sint = Webhookdb::Fixtures.service_integration.create(sint) unless sint.is_a?(Webhookdb::ServiceIntegration)
    self.organization = sint.organization
    self.service_integration_opaque_id = sint.opaque_id
  end

  decorator :body do |b|
    self.request_body = b.is_a?(String) ? b : b.to_json
  end

  decorator :headers do |h|
    self.request_headers.merge!(h)
  end
end
