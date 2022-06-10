# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseWireTransferV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_wire_transfer_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseWireTransferV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Increase Wire Transfer",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:account_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:routing_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:approved_at, TIMESTAMP),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:template_id, TEXT),
      Webhookdb::Services::Column.new(:transaction_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:updated_at, TIMESTAMP, index: true),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "wire_transfer")
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      amount: obj_of_interest.fetch("amount"),
      account_number: obj_of_interest.fetch("account_number"),
      account_id: obj_of_interest.fetch("account_id"),
      routing_number: obj_of_interest.fetch("routing_number"),
      approved_at: obj_of_interest.fetch("approval").fetch("approved_at"),
      created_at: obj_of_interest.fetch("created_at"),
      increase_id: obj_of_interest.fetch("id"),
      status: obj_of_interest.fetch("status"),
      template_id: obj_of_interest.fetch("template_id"),
      transaction_id: obj_of_interest.fetch("transaction_id"),
      updated_at: updated,
    }
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/wire_transfers"
  end
end
