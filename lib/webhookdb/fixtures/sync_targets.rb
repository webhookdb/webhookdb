# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::SyncTargets
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::SyncTarget

  base :sync_target do
    self.period_seconds ||= Faker::Number.between(from: 30.seconds.to_i, to: 24.hours.to_i)
    self.connection_url ||= Webhookdb::Postgres::Model.uri
  end

  before_saving do |instance|
    instance.service_integration ||= Webhookdb::Fixtures.service_integration.create
    instance
  end

  decorator :postgres do
    self.connection_url = Webhookdb::Postgres::Model.uri
  end

  decorator :snowflake do
    self.connection_url = Webhookdb::Snowflake.test_url
  end

  decorator :https do |url=nil|
    self.connection_url = url || Faker::Internet.url
  end
end
