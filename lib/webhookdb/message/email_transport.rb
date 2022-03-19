# frozen_string_literal: true

require "appydays/configurable"
require "premailer"

require "webhookdb/message/transport"
require "webhookdb/postmark"

class Webhookdb::Message::EmailTransport < Webhookdb::Message::Transport
  include Appydays::Configurable

  register_transport(:email)

  configurable(:email) do
    setting :allowlist, ["*@lithic.tech"], convert: ->(s) { s.split }
    setting :from, "WebhookDB <webhookdb@lithic.tech>"
  end

  def type
    return :email
  end

  def service
    return "postmark"
  end

  def supports_layout?
    return true
  end

  def add_bodies(delivery, content)
    pm = Premailer.new(
      content.to_s,
      with_html_string: true,
      warn_level: Premailer::Warnings::SAFE,
    )

    begin
      subject = content[:subject]
    rescue TypeError, NoMethodError
      subject = nil
    end

    raise "content %p is missing a subject" % content unless subject

    bodies = []
    bodies << delivery.add_body(content: content[:subject], mediatype: "subject")
    bodies << delivery.add_body(content: pm.to_plain_text, mediatype: "text/plain")
    bodies << delivery.add_body(content: pm.to_inline_css, mediatype: "text/html")
    return bodies
  end

  def allowlisted?(address)
    return self.class.allowlist.any? { |pattern| File.fnmatch(pattern, address) }
  end

  def send!(delivery)
    unless allowlisted?(delivery.to)
      raise Webhookdb::Message::Transport::UndeliverableRecipient,
            "#{delivery.to} is not allowlisted"
    end

    from = delivery.extra_fields["from"].present? ? delivery.extra_fields["from"] : self.class.from
    begin
      response = Webhookdb::Postmark.send_email(
        from,
        delivery.to,
        delivery.body_with_mediatype("subject")&.content,
        plain: delivery.body_with_mediatype!("text/plain")&.content,
        html: delivery.body_with_mediatype!("text/html")&.content,
        to_name: delivery.recipient&.name,
        reply_to: delivery.extra_fields["reply_to"],
      )
    rescue Postmark::InactiveRecipientError => e
      raise Webhookdb::Message::Transport::UndeliverableRecipient, "#{delivery.to} cannot be reached: #{e.inspect}"
    rescue Postmark::InvalidEmailAddressError => e
      raise Webhookdb::Message::Transport::UndeliverableRecipient, "#{delivery.to} email is invalid: #{e.inspect}"
    else
      raise Webhookdb::Message::Transport::Error, response.inspect if response[:error_code].positive?
      return response[:message_id]
    end
  end

  protected def extract_email_part(email)
    split = /(?:(?<address>.+)\s)?<?(?<email>.+@[^>]+)>?/.match(email)
    return split[:email]
  end
end
