# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

module Webhookdb::Signalwire
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:signalwire) do
    setting :http_timeout, 30
    setting :sms_allowlist, [], convert: lambda(&:split)
  end

  def self.send_sms(from:, to:, body:, project_id:, media_urls: [], **kw)
    sms_allowed = self.sms_allowlist.any? { |pattern| File.fnmatch(pattern, to) }
    unless sms_allowed
      self.logger.warn("signalwire_sms_not_allowed", to:)
      return {"sid" => "skipped"}
    end
    req_body = {
      From: from,
      To: to,
      Body: body,
    }
    req_body[:MediaUrl] = media_urls if media_urls.present?
    return self.http_request(
      :post,
      "/2010-04-01/Accounts/#{project_id}/Messages.json",
      body: req_body,
      project_id:,
      **kw,
    )
  end

  def self.http_request(method, tail, space_url:, project_id:, api_key:, logger:, headers: {}, body: nil, **kw)
    url = "https://#{space_url}.signalwire.com" + tail
    headers["Content-Type"] ||= "application/x-www-form-urlencoded"
    headers["Accept"] ||= "application/json"
    kw[:body] = URI.encode_www_form(body) if body
    resp = Webhookdb::Http.send(
      method,
      url,
      basic_auth: {
        username: project_id,
        password: api_key,
      },
      logger:,
      timeout: self.http_timeout,
      headers:,
      **kw,
    )
    return resp.parsed_response
  end
end
