# frozen_string_literal: true

require "httparty"

class Webhookdb::Services::TwilioSmsV1 < Webhookdb::Services::Base
  include Appydays::Loggable

  def webhook_response(request)
    auth = request.get_header("Authorization")
    if auth.nil? || !auth.match(/^Basic /)
      return [401, {"Content-Type" => "text/plain", "WWW-Authenticate" => 'Basic realm="Webhookdb"'}, ""]
    end
    user_and_pass = Base64.decode64(auth.gsub(/^Basic /, ""))
    return [401, {"Content-Type" => "text/plain"}, ""] if user_and_pass != self.service_integration.webhook_secret
    return [202, {"Content-Type" => "text/xml"}, "<Response></Response>"]
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:twilio_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:date_created, "timestamptz"),
      Webhookdb::Services::Column.new(:date_sent, "timestamptz"),
      Webhookdb::Services::Column.new(:date_updated, "timestamptz"),
      Webhookdb::Services::Column.new(:direction, "text"),
      Webhookdb::Services::Column.new(:from, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:to, "text"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:date_updated] < Sequel[:excluded][:date_updated]
  end

  def _prepare_for_insert(body)
    return {
      twilio_id: body["sid"],
      date_created: Time.parse(body["date_created"]),
      date_sent: Time.parse(body["date_sent"]),
      date_updated: Time.parse(body["date_updated"]),
      direction: body["direction"],
      from: body["from"],
      status: body["status"],
      to: body["to"],
    }
  end

  def _fetch_backfill_page(pagination_token)
    unless (url = pagination_token)
      date_send_max = Date.tomorrow
      url = "/2010-04-01/Accounts/#{self.service_integration.backfill_key}/Messages.json" \
        "?PageSize=100&DateSend%3C=#{date_send_max}"
    end
    url = "https://api.twilio.com" + url
    response = HTTParty.get(
      url,
      basic_auth: {username: self.service_integration.backfill_key,
                   password: self.service_integration.backfill_secret,},
      logger: self.logger,
    )
    raise response if response.code >= 300
    data = response.parsed_response
    return data["messages"], data["next_page_uri"]
  end
end
