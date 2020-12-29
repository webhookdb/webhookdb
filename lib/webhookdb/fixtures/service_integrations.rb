# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"
require "webhookdb/service_integration"

module Webhookdb::Fixtures::ServiceIntegrations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::ServiceIntegration

  base :service_integration do
  end

  before_saving do |instance|
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end
end
