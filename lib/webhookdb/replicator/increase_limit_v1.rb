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
      ctor: ->(sint) { Webhookdb::Replicator::IncreaseLimitV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Increase Limit",
      supports_webhooks: true,
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
        event_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
      Webhookdb::Replicator::Column.new(
        :row_updated_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:value, INTEGER),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _resource_and_event(request)
    return self._find_resource_and_event(request.body, "limit")
  end

  def _upsert_update_expr(inserting, **_kwargs)
    update = super
    # Only set created_at if it's not set so the initial insert isn't modified.
    self._coalesce_excluded_on_update(update, [:row_created_at])
    return update
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/limits"
  end
end
