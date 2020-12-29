# frozen_string_literal: true

require "webhookdb/message/transport"

class Webhookdb::Message::FakeTransport < Webhookdb::Message::Transport
  extend Webhookdb::MethodUtilities

  register_transport(:fake)

  singleton_attr_reader :sent_deliveries
  @sent_deliveries = []

  singleton_attr_accessor :disable_func
  @disable_func = nil

  def self.reset!
    self.sent_deliveries.clear
    self.disable_func = nil
  end

  def type
    return :fake
  end

  def service
    return "fake"
  end

  def supports_layout?
    return true
  end

  def add_bodies(delivery, content)
    bodies = []
    bodies << delivery.add_body(content: content.to_s, mediatype: "text/plain")
    return bodies
  end

  def send!(delivery)
    if Webhookdb::Message::FakeTransport.disable_func&.call(delivery)
      Webhookdb.logger.debug "Did not deliver Delivery[%d] to %s because it was skipped by disable_func" %
        [delivery.id, delivery.to]
      return nil
    end

    Webhookdb.logger.debug "Storing Delivery[%d] to %s as sent" % [delivery.id, delivery.to]
    Webhookdb::Message::FakeTransport.sent_deliveries << delivery
    return "#{delivery.id}-#{SecureRandom.hex(6)}"
  end
end
