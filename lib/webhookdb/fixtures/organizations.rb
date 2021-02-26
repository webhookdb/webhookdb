# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::Organizations
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Organization

  base :organization do
    self.name ||= Faker::Business.name + SecureRandom.hex(2)
  end
end
