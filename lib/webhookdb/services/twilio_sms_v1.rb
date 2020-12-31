# frozen_string_literal: true

class Webhookdb::Services::TwilioSmsV1 < Webhookdb::Services::Base
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

  def _prepare_for_insert(_headers, body)
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
end
