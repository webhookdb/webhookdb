# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/replicator/increase_v1_mixin"

class Webhookdb::Replicator::IncreaseLimitV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_limit_v1",
      ctor: self,
      # This is a legacy resource. Instead, users should set the 'allow/deny ACH debits' flag on account numbers,
      # or use the Inbound ACH Transfer object, which can send a webhook to accept or reject it.
      # This flag is here for WebhookDB users who still need access to Limit resources.
      feature_roles: ["increase_limits"],
      resource_name_singular: "Increase Limit",
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
      Webhookdb::Replicator::Column.new(:interval, TEXT),
      Webhookdb::Replicator::Column.new(:metric, TEXT),
      Webhookdb::Replicator::Column.new(:model_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:model_type, TEXT),
      Webhookdb::Replicator::Column.new(
        :row_created_at,
        TIMESTAMP,
        data_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, data_key: "updated_at", index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:value, INTEGER),
    ]
  end

  def _timestamp_column_name = :row_updated_at

  def _mixin_object_type = "limit"
end
