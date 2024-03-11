# frozen_string_literal: true

require "webhookdb/replicator/increase_v1_mixin"

class Webhookdb::Replicator::IncreaseTransactionV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_transaction_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Increase Transaction",
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
      Webhookdb::Replicator::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, index: true),
      # date is a legacy field that is not documented in the API,
      # but is still sent with transactions as of April 2022.
      # We need to support the v1 schema, but do not want to depend
      # on Increase continuing to send a transaction resource 'date' field.
      Webhookdb::Replicator::Column.new(
        :date,
        DATE,
        index: true,
        data_key: "created_at",
        optional: true,
        converter: Webhookdb::Replicator::Column::CONV_TO_UTC_DATE,
      ),
      Webhookdb::Replicator::Column.new(:route_id, TEXT, index: true),
    ]
  end

  def _mixin_object_type = "transaction"
end
