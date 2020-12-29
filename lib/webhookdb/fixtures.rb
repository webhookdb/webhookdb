# frozen_string_literal: true

require "faker"
require "fluent_fixtures"

require "webhookdb"

module Webhookdb::Fixtures
  extend FluentFixtures::Collection

  # Set the path to use when finding fixtures for this collection
  fixture_path_prefix "webhookdb/fixtures"

  ::Faker::Config.locale = :en
end
