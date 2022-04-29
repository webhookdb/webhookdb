# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::ServiceIntegrations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::ServiceIntegration

  base :service_integration do
    self.service_name ||= "fake_v1"
    self.table_name ||= "#{self.service_name}_#{SecureRandom.hex(2)}"
    self.api_url ||= "https://fake-url.com"
  end

  before_saving do |instance|
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end

  decorator :depending_on do |other|
    self.depends_on = other
  end
end
