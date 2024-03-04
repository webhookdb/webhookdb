# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::Roles
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Role

  base :role do
    self.name ||= Faker::Lorem.word + SecureRandom.hex(2)
  end
end
