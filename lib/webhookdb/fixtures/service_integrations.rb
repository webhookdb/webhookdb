# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::ServiceIntegrations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::ServiceIntegration

  base :service_integration do
    self.service_name ||= "fake_v1"
    self.api_url ||= "https://fake-url.com"
  end

  before_saving do |instance|
    instance.table_name ||= "#{instance.service_name}_#{SecureRandom.hex(2)}"
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end

  decorator :depending_on do |other|
    self.depends_on = other
  end

  decorator :stable_encryption_secret do
    self.data_encryption_secret = "6vHQcB8xlVSmHO2Wxsqk713k7oi_SpIWirUG0YTGUa4="
  end

  decorator :with_encryption_secret do
    self.data_encryption_secret = Webhookdb::Crypto.encryption_key.base64
  end
end
