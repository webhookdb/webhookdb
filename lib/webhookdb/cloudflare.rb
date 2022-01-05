# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

class Webhookdb::Cloudflare
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:cloudflare) do
    setting :api_token, "set-me-to-token"
    setting :host, "https://api.cloudflare.com"
  end

  def self.headers
    return {
      "Authorization" => "Bearer #{self.api_token}",
    }
  end

  # https://api.cloudflare.com/#dns-records-for-a-zone-create-dns-record
  def self.create_zone_dns_record(name:, content:, zone_id:, type: "CNAME", ttl: 1)
    body = {
      type:,
      name:,
      content:,
      ttl:,
    }
    response = Webhookdb::Http.post(
      self.host + "/client/v4/zones/#{zone_id}/dns_records",
      body,
      headers: self.headers,
      logger: self.logger,
    )
    return Yajl::Parser.parse(response.body)
  end
end
