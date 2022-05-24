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
      resource_name_singular: "Increase ACH Transfer",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:routing_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:transaction_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP, index: true),
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

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/transfers/achs"
  end
end
