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
    return Webhookdb::Services::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(:approved_at, TIMESTAMP, data_key: ["approval", "approved_at"]),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, optional: true, index: true),
      Webhookdb::Services::Column.new(:routing_number, TEXT, index: true),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:template_id, TEXT),
      Webhookdb::Services::Column.new(:transaction_id, TEXT, index: true),
      Webhookdb::Services::Column.new(
        :updated_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
    ]
  end

  def _resource_and_event(request)
    return self._find_resource_and_event(request.body, "wire_transfer")
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/wire_transfers"
  end
end
