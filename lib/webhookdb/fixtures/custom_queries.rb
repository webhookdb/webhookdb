# frozen_string_literal: true

require "faker"

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::CustomQueries
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::CustomQuery

  base :custom_query do
    self.description ||= Faker::Lorem.sentence
    self.sql ||= "SELECT * FROM mytable"
  end

  before_saving do |instance|
    instance.organization ||= Webhookdb::Fixtures.organization.create
    instance
  end

  decorator :created_by do |c={}|
    c = Webhookdb::Fixtures.customer.create(c) unless c.is_a?(Webhookdb::Customer)
    self.created_by = c
  end
end
