# frozen_string_literal: true

require "webhookdb/message"

class Webhookdb::Message::Transport
  extend Webhookdb::MethodUtilities

  class Error < StandardError; end
  class UndeliverableRecipient < Error; end

  singleton_attr_reader :transports
  @transports = {}

  singleton_attr_accessor :override

  def self.register_transport(type)
    Webhookdb::Message::Transport.transports[type] = self.new
  end

  def self.for(type)
    type = Webhookdb::Message::Transport.override || type
    return Webhookdb::Message::Transport.transports[type.to_sym]
  end

  def self.for!(type)
    (t = self.for(type)) or raise Webhookdb::Message::InvalidTransportError, "invalid transport: %p" % type
    return t
  end

  # Override this if a transport needs a different 'to' than the email,
  # like for text messages.
  def recipient(to)
    if to.is_a?(Webhookdb::Customer)
      (email = to.email) or raise "Customer #{to.id} has no default email"
      return Webhookdb::Message::Recipient.new(email, to)
    end
    return Webhookdb::Message::Recipient.new(to, nil)
  end

  def send!(_delivery)
    raise "Must implement in subclass. Call 3rd party with message/content and return transport ID."
  end
end
