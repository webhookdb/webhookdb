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
    return Webhookdb::Services::Column.new(:increase_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:interval, TEXT),
      Webhookdb::Services::Column.new(:metric, TEXT),
      Webhookdb::Services::Column.new(:model_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:model_type, TEXT),
      Webhookdb::Services::Column.new(:status, TEXT),
      Webhookdb::Services::Column.new(:value, INTEGER),
      Webhookdb::Services::Column.new(:row_created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, index: true),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "limit")
    obj_of_interest, updated = self._extract_obj_and_updated(body, default: Time.now)
    return {
      data: obj_of_interest.to_json,
      interval: obj_of_interest.fetch("interval"),
      metric: obj_of_interest.fetch("metric"),
      model_id: obj_of_interest.fetch("model_id"),
      model_type: obj_of_interest.fetch("model_type"),
      increase_id: obj_of_interest.fetch("id"),
      status: obj_of_interest.fetch("status"),
      value: obj_of_interest.fetch("value"),
      row_created_at: updated, # See upsert_update_expr
      row_updated_at: updated,
    }
  end

  def _upsert_update_expr(inserting, **_kwargs)
    # Only set created_at if it's not set so the initial insert isn't modified.
    update = inserting.dup
    update[:row_created_at] = Sequel.function(
      :coalesce, self.qualified_table_sequel_identifier[:row_created_at], Sequel[:excluded][:row_created_at],
    )
    return update
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/limits"
  end
end
