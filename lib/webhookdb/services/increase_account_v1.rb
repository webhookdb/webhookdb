# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseAccountV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_account_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseAccountV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "Increase Account",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:balance, "integer", index: true),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:entity_id, "text", index: true),
      Webhookdb::Services::Column.new(:interest_accrued, "numeric"),
      Webhookdb::Services::Column.new(:name, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "account")
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      balance: obj_of_interest.fetch("balance"),
      created_at: obj_of_interest.fetch("created_at"),
      entity_id: obj_of_interest.fetch("entity_id"),
      increase_id: obj_of_interest.fetch("id"),
      interest_accrued: obj_of_interest.fetch("interest_accrued"),
      name: obj_of_interest.fetch("name"),
      status: obj_of_interest.fetch("status"),
      updated_at: updated,
    }
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/accounts"
  end
end
