# frozen_string_literal: true

require "webhookdb"
require "webhookdb/fixtures"

module Webhookdb::Fixtures::ResetCodes
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Customer::ResetCode

  base :reset_code do
    self.transport ||= ["sms", "email"].sample
  end

  before_saving do |instance|
    instance.customer ||= Webhookdb::Fixtures.customer.create
    instance
  end

  decorator :sms do
    self.transport = "sms"
  end

  decorator :email do
    self.transport = "email"
  end
end
