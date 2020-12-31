# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_verified
  singleton_attr_accessor :webhook_response_body
  singleton_attr_accessor :webhook_response_headers
  singleton_attr_accessor :webhook_response_content_type

  def self.reset
    self.webhook_verified = true
    self.webhook_response_body = nil
    self.webhook_response_headers = nil
    self.webhook_response_content_type = nil
  end

  def webhook_http_request_verified?(_request)
    return self.class.webhook_verified
  end

  def webhook_response_body
    return self.class.webhook_response_body || super
  end

  def webhook_response_headers
    return self.class.webhook_response_headers || super
  end

  def webhook_response_content_type
    return self.class.webhook_response_content_type || super
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:my_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:at, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:at] < Sequel[:excluded][:at]
  end

  def _prepare_for_insert(_headers, body)
    return {
      my_id: body["my_id"],
      at: Time.parse(body["at"]),
    }
  end
end
