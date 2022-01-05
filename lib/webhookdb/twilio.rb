# frozen_string_literal: true

require "twilio-ruby"

require "appydays/configurable"
require "appydays/loggable"
require "webhookdb/method_utilities"

module Webhookdb::Twilio
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  singleton_attr_accessor :client

  configurable(:twilio) do
    setting :account_sid, "AC444test"
    setting :auth_token, "ac45test"

    after_configured do
      @client = Twilio::REST::Client.new(self.account_sid, self.auth_token)
    end
  end

  # def self.send_auth_sms(to:, token:)
  #   self.client.messages.create(
  #     from: self.auth_phone,
  #     to: to,
  #     body: "Your Webhookdb verification code is: #{token}",
  #   )
  # end

  def self.send_sms(from, to, body)
    self.client.messages.create(
      from:,
      to:,
      body:,
    )
  rescue Twilio::REST::RestError => e
    if e.code == 21_211
      self.logger.warn("twilio_invalid_phone_number", phone: to, body:, error: e.response.body)
      return nil
    end
    raise e
  end
end
