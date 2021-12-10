# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseACHTransferV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_number, "text"),
      Webhookdb::Services::Column.new(:account_id, "text"),
      Webhookdb::Services::Column.new(:amount, "numeric"),
      Webhookdb::Services::Column.new(:created_at, "timestamptz"),
      Webhookdb::Services::Column.new(:routing_number, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:transaction_id, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = Webhookdb::Increase.find_desired_object_data(body)
    return nil unless Webhookdb::Increase.contains_desired_object(obj_of_interest, "ach_transfer")

    updated = if body.key?("event")
                # i.e. if this is a webhook
                body["created_at"]
    else
      obj_of_interest["created_at"]
              end

    return {
      account_number: obj_of_interest["account_number"],
      account_id: obj_of_interest["account_id"],
      amount: obj_of_interest["amount"],
      created_at: obj_of_interest["created_at"],
      increase_id: obj_of_interest["id"],
      routing_number: obj_of_interest["routing_number"],
      status: obj_of_interest["status"],
      transaction_id: obj_of_interest["transaction_id"],
      updated_at: updated,
    }
  end

  def _mixin_name_singular
    return "Increase ACH Transfer"
  end

  def _mixin_name_plural
    return "Increase ACH Transfers"
  end

  def _mixin_backfill_url
    return "https://api.increase.com/transfers/achs"
  end
end
