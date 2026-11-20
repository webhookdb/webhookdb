# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::SavedViews
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::SavedView

  base :saved_view do
    self.name ||= "testview_#{SecureRandom.hex(3)}"
    self.sql ||= "SELECT 'fixtured' AS testcol"
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
