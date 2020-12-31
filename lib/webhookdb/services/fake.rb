# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :webhook_verified

  def self.reset
    self.webhook_response = nil
    self.webhook_verified = true
  end

  def webhook_response(request)
    return self.class.webhook_response || super
  end

  def _webhook_verified?(_request)
    return self.class.webhook_verified
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
