# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :webhook_verified
  singleton_attr_accessor :backfill_responses

  def self.reset
    self.webhook_response = nil
    self.webhook_verified = true
    self.backfill_responses = {}
  end

  def webhook_response(request)
    return self.class.webhook_response || super
  end

  def process_state_change(_field, _value)
    return self.calculate_create_state_machine(nil)
  end

  def calculate_create_state_machine(_organization)
    return Webhookdb::Services::StateMachineStep.new
  end

  def calculate_backfill_state_machine(_organization)
    return Webhookdb::Services::StateMachineStep.new.mark_complete
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

  def _prepare_for_insert(body)
    return {
      my_id: body["my_id"],
      at: Time.parse(body["at"]),
    }
  end

  def _fetch_backfill_page(pagination_token)
    raise "No backfill responses configured" if self.class.backfill_responses.blank?
    return self.class.backfill_responses[pagination_token]
  end
end
