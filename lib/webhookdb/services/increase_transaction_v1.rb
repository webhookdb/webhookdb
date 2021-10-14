# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseTransactionV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_id, "text"),
      Webhookdb::Services::Column.new(:amount, "text"),
      Webhookdb::Services::Column.new(:date, "date"),
      Webhookdb::Services::Column.new(:route_id, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz"),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest = Webhookdb::Increase.find_desired_object_data(body)
    return nil unless Webhookdb::Increase.contains_desired_object(obj_of_interest, "transaction")

    updated = if body.key?("event")
                # i.e. if this is a webhook
                body["created_at"]
    else
      obj_of_interest["created_at"]
              end

    return {
      account_id: obj_of_interest["account_id"],
      amount: obj_of_interest["amount"],
      date: obj_of_interest["date"],
      increase_id: obj_of_interest["id"],
      route_id: obj_of_interest["route_id"],
      updated_at: updated,
    }
  end

  def _mixin_name_singular
    return "Increase Transaction"
  end

  def _mixin_name_plural
    return "Increase Transactions"
  end

  def _mixin_backfill_url
    return "https://api.increase.com/transactions"
  end
end