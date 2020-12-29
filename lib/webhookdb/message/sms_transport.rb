# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"
require "webhookdb/message/transport"
require "webhookdb/twilio"

class Webhookdb::Message::SmsTransport < Webhookdb::Message::Transport
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  # Given a string representing a phone number, returns that phone number in E.164 format (+1XXX5550100).
  # Assumes all provided phone numbers are US numbers.
  # Does not check for invalid area codes.
  def self.format_phone(phone)
    return nil if phone.blank?
    return phone if /^\+1\d{10}$/.match?(phone)
    phone = phone.gsub(/\D/, "")
    return "+1" + phone if phone.size == 10
    return "+" + phone if phone.size == 11
  end

  register_transport(:sms)

  configurable(:sms) do
    setting :allowlist,
            ["+1555*"],
            # NOTE: format_phone must be defined before this is called
            convert: ->(s) { s.split.map { |p| Webhookdb::Message::SmsTransport.format_phone(p) || p } }
    setting :from, "17742606953"
  end

  def type
    return :sms
  end

  def service
    return "twilio"
  end

  def supports_layout?
    false
  end

  def recipient(to)
    return Webhookdb::Message::Recipient.new(to.phone, to) if to.is_a?(Webhookdb::Customer)
    return Webhookdb::Message::Recipient.new(to, nil)
  end

  def allowlisted?(phone)
    return self.class.allowlist.any? { |pattern| File.fnmatch(pattern, phone) }
  end

  def send!(delivery)
    # The number provided to Twilio must be a phone number in E.164 format.
    formatted_phone = self.class.format_phone(delivery.to)
    raise Webhookdb::Message::Transport::Error, "Could not format phone number" if formatted_phone.nil?

    return nil unless self.allowlisted?(formatted_phone)

    body = delivery.bodies.first.content
    self.logger.info("send_twilio_sms", to: formatted_phone, message_preview: body.slice(0, 20))
    response = Webhookdb::Twilio.send_sms(self.class.from, formatted_phone, body)
    self.logger.debug { "Response from Twilio: %p" % [response] }
    return nil if response.nil?
    return response.sid
  end

  def add_bodies(delivery, content)
    bodies = []
    raise "content is not set" if content.blank?
    bodies << delivery.add_body(content: content, mediatype: "text/plain")
    return bodies
  end
end
