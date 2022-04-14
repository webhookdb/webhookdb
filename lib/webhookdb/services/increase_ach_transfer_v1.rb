# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseACHTransferV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_ach_transfer_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseACHTransferV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_number, "text", index: true),
      Webhookdb::Services::Column.new(:account_id, "text", index: true),
      Webhookdb::Services::Column.new(:amount, "numeric", index: true),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:routing_number, "text", index: true),
      Webhookdb::Services::Column.new(:status, "text", index: true),
      Webhookdb::Services::Column.new(:transaction_id, "text", index: true),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "ach_transfer")
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      account_number: obj_of_interest.fetch("account_number"),
      account_id: obj_of_interest.fetch("account_id"),
      amount: obj_of_interest.fetch("amount"),
      created_at: obj_of_interest.fetch("created_at"),
      increase_id: obj_of_interest.fetch("id"),
      routing_number: obj_of_interest.fetch("routing_number"),
      status: obj_of_interest.fetch("status"),
      transaction_id: obj_of_interest.fetch("transaction_id"),
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
