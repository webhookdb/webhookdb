# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::NewCustomer < Webhookdb::Message::Template
  def self.fixtured(recipient)
    return self.new(recipient)
  end

  def initialize(customer)
    @customer = customer
    super()
  end
end
