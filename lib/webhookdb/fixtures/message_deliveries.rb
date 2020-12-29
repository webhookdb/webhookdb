# frozen_string_literal: true

require "faker"

require "webhookdb/fixtures"
require "webhookdb/message/delivery"

module Webhookdb::Fixtures::MessageDeliveries
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Message::Delivery

  depends_on(:customers)

  base :message_delivery do
    self.template ||= "fixture"
    self.transport_type ||= "fake"
    self.transport_service ||= "fixture"
    self.to ||= "fixture-to"
  end

  decorator :email, presave: true do |to=nil|
    self.transport_type = "email"
    self.to = to || self.recipient&.email || Faker::Internet.email
    self.add_body(mediatype: "subject", content: Faker::Lorem.sentence)
    self.add_body(mediatype: "text/plain", content: Faker::Lorem.paragraph)
    self.add_body(mediatype: "text/html", content: "<html><body><p>#{Faker::Lorem.sentence}</p></body></html>")
  end

  decorator :sms, presave: true do |to=nil, content: nil|
    self.transport_type = "sms"
    self.to = to || self.recipient&.phone || Faker::PhoneNumber.cell_phone
    self.add_body(mediatype: "text/plain", content: content || Faker::Lorem.paragraph)
  end

  decorator :to do |recipient=nil|
    recipient = self.transport!.recipient(recipient)
    self.to = recipient.to
    self.recipient = recipient.customer
  end

  decorator :with_recipient do |customer={}|
    customer = Webhookdb::Fixtures.customer.create(customer) unless customer.is_a?(Webhookdb::Customer)
    self.recipient = customer
  end

  decorator :with_body, presave: true do |body={}|
    body[:mediatype] ||= Faker::Lorem.word
    body[:content] ||= Faker::Lorem.sentences
    self.add_body(body)
  end

  decorator :via do |transport|
    self.transport_type = transport
    self.to = self.transport!.recipient(self.recipient).to if self.recipient
  end

  decorator :sent do |at=nil|
    at ||= Time.now
    self.sent_at = at
  end

  decorator :extra do |k, v|
    self.extra_fields[k.to_s] = v
  end
end
