# frozen_string_literal: true

require "securerandom"

require "webhookdb"
require "webhookdb/fixtures"
require "webhookdb/oauth/session"

module Webhookdb::Fixtures::OauthSessions
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Oauth::Session

  base :oauth_session do
    self.oauth_state ||= SecureRandom.hex(16)
    self.peer_ip ||= Faker::Internet.ip_v4_address
    self.user_agent ||= "(unset)"
  end

  decorator :for_customer, presave: true do |c={}|
    c = Webhookdb::Fixtures.customer.create(c) unless c.is_a?(Webhookdb::Customer)
    self.customer ||= c
  end
end
