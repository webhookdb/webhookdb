# frozen_string_literal: true

require "webhookdb/replicator/increase_v1_mixin"

class Webhookdb::Replicator::IncreaseACHTransferV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_ach_transfer_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Increase ACH Transfer",
      dependency_descriptor: Webhookdb::Replicator::IncreaseAppV1.descriptor,
      supports_backfill: true,
      api_docs_url: "https://increase.com/documentation/api",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:account_number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:routing_number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:transaction_id, TEXT, index: true),
    ]
  end

  def _mixin_object_type = "ach_transfer"
end
