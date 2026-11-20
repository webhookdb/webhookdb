# frozen_string_literal: true

require "faker"

require "webhookdb/fixtures"

module Webhookdb::Fixtures::OrganizationErrorHandlers
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Organization::ErrorHandler

  base :organization_error_handler do
    self.url ||= Faker::Internet.url
  end

  before_saving do |instance|
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end
end
