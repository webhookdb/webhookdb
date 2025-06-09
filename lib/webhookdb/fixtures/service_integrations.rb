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

  STABLE_ENC_SECRET = "6vHQcB8xlVSmHO2Wxsqk713k7oi_SpIWirUG0YTGUa4="
  decorator :stable_encryption_secret do
    self.data_encryption_secret = STABLE_ENC_SECRET
  end

  decorator :with_secrets do
    self.webhook_secret = "fake_whsecret"
    self.backfill_key = "fake_bfkey"
    self.backfill_secret = "fake_bfsecret"
  end

  decorator :with_api_key do
    self.webhookdb_api_key ||= self.new_api_key
  end
end
