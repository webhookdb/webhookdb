# frozen_string_literal: true

require "appydays/configurable"
require "mail"
require "premailer"

require "webhookdb/message/transport"

class Webhookdb::Message::EmailTransport < Webhookdb::Message::Transport
  include Appydays::Configurable

  register_transport(:email)

  configurable(:email) do
    setting :allowlist, ["*@lithic.tech", "*@webhookdb.com"], convert: ->(s) { s.split }
    setting :from, "WebhookDB <hello@webhookdb.com>"

    setting :smtp_host, "localhost"
    setting :smtp_port, 18_012
    setting :smtp_user, ""
    setting :smtp_password, ""
    setting :smtp_starttls, false

    # If this is a recognized value, certain special behavior is used,
    # particularly around message ids and metadata.
    # Currently supported values:
    #
    # - postmark: Set the X-PM-Metadata-messageid field and some other fields.
    #
    # If you need other behavior, you can open an issue or pull request.
    # Unsupported values are ignored.
    setting :smtp_provider, ""
    # Additional headers sent in each email.
    setting :smtp_headers, {}, convert: ->(s) { JSON.parse(s) }

    # Only really used during testing and development.
    # We don't expect this to be running in production.
    setting :mailpit_url, "http://localhost:18011"
  end

  def type
    return :email
  end

  def service
    return "smtp"
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
    to = self.format_email_name(delivery.to, delivery.recipient&.name)
    message_id = SecureRandom.uuid.to_s
    this = self
    Mail.deliver do
      delivery_method(
        :smtp,
        address: this.class.smtp_host,
        port: this.class.smtp_port,
        user_name: this.class.smtp_user,
        password: this.class.smtp_password,
        enable_starttls_auto: this.class.smtp_starttls,
      )
      this.class.smtp_headers.each do |k, v|
        header[k] = v
      end
      custom_method = :"_handle_#{this.class.smtp_provider}"
      this.send(custom_method, delivery, self, message_id) if this.respond_to?(custom_method)
      from from
      to to
      reply_to(delivery.extra_fields["reply_to"]) if delivery.extra_fields["reply_to"].present?
      subject delivery.body_with_mediatype("subject")&.content
      text_part do
        content_type "text/plain; charset=UTF-8"
        body delivery.body_with_mediatype!("text/plain")&.content
      end
      html_part do
        content_type "text/html; charset=UTF-8"
        body delivery.body_with_mediatype!("text/html")&.content
      end
    end
    return message_id
  end

  protected def extract_email_part(email)
    split = /(?:(?<address>.+)\s)?<?(?<email>.+@[^>]+)>?/.match(email)
    return split[:email]
  end

  def format_email_name(email, name)
    return email if name.blank?
    return "#{name} <#{email}>"
  end

  def _handle_postmark(delivery, mail, message_id)
    mail.header["X-PM-Metadata-messageid"] = message_id
    mail.header["X-PM-Tag"] = delivery.template
  end
end
