# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::Verification < Webhookdb::Message::Template
  def self.fixtured(recipient)
    code = Webhookdb::Fixtures.reset_code(customer: recipient).create
    return self.new(code)
  end

  def initialize(reset_code)
    @reset_code = reset_code
    super()
  end

  def liquid_drops
    return super.merge(
      expire_at: @reset_code.expire_at,
      token: @reset_code.token,
      email: @reset_code.customer.email,
    )
  end
end
