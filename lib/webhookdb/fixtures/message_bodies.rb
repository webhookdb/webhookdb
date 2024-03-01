# frozen_string_literal: true

require "webhookdb/fixtures"

module Webhookdb::Fixtures::MessageBody
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::Message::Body

  base :message_body do
    self.mediatype ||= "text/plain"
    self.content ||= Faker::Lorem.paragraph
  end

  before_saving do |instance|
    instance.delivery ||= Webhookdb::Fixtures.message_delivery.create
    instance
  end

  decorator :html do
    self.mediatype = "text/html"
    self.content = "<html><body><p>#{Faker::Lorem.sentence}</p></body></html>"
  end

  decorator :text do
    self.mediatype = "text/plain"
    self.content = Faker::Lorem.paragraph
  end

  decorator :subject do
    self.mediatype = "subject"
    self.content = Faker::Lorem.sentence
  end
end
