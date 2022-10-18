# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseLimitV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_limit_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseLimitV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Increase Limit",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:interval, TEXT),
      Webhookdb::Services::Column.new(:metric, TEXT),
      Webhookdb::Services::Column.new(:model_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:model_type, TEXT),
      Webhookdb::Services::Column.new(
        :row_created_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
      Webhookdb::Services::Column.new(
        :row_updated_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        optional: true,
        index: true,
      ),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:value, INTEGER),
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
    # Only set created_at if it's not set so the initial insert isn't modified.
    return self._coalesce_excluded_on_update(inserting, [:row_created_at])
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/limits"
  end
end
