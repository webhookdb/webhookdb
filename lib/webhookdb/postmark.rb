# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"
require "postmark"

Postmark.response_parser_class = :Json

module Webhookdb::Postmark
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  class Error < StandardError; end

  configurable(:postmark) do
    setting :api_key, "postmark-key"
    setting :sandbox_mode, true
    # See https://postmarkapp.com/support/article/800-ips-for-firewalls#webhooks
    setting :allowed_ips,
            ["127.0.0.1", "3.134.147.250", "50.31.156.6", "50.31.156.77", "18.217.206.57"],
            convert: ->(s) { s.split.map(&:strip) }
  end

  # Return a new Postmark client.
  # Because creating the client creates a new HTTP::Net instance, it is not mocked during testing.
  # So we create a new instance on-demand.
  #
  # @return [Postmark::ApiClient]
  def self.api
    key = self.sandbox_mode ? "POSTMARK_API_TEST" : self.api_key
    return ::Postmark::ApiClient.new(key)
  end

  def self.send_email(from, to, subject, plain: nil, html: nil, to_name: nil, reply_to: nil)
    self.logger.info "Sending email to %p through Postmark: %p" % [subject, to]

    params = {
      from:,
      to: self.format_to(to, to_name),
      subject:,
    }
    params[:reply_to] = reply_to if reply_to
    params[:text_body] = plain if plain
    params[:html_body] = html if html

    response = self.api.deliver(params)
    if response[:error_code].positive?
      self.logger.warn "postmark_error", postmark_response: response
    else
      self.logger.debug "postmark_sent", postmark_response: response
    end
    return response
  end

  def self.format_to(email, name)
    return email if name.blank?
    return "#{name} <#{email}>"
  end

  def self.webhook_response(request)
    ip = request.ip
    allowed = self.allowed_ips.include?(ip)
    return allowed ? Webhookdb::WebhookResponse.ok : Webhookdb::WebhookResponse.error("invalid ip")
  end
end
