# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/services/increase_v1_mixin"

class Webhookdb::Services::IncreaseTransactionV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::IncreaseV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "increase_transaction_v1",
      ctor: ->(sint) { Webhookdb::Services::IncreaseTransactionV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Increase Transaction",
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:increase_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_id, "text", index: true),
      Webhookdb::Services::Column.new(:amount, "integer", index: true),
      Webhookdb::Services::Column.new(:created_at, "timestamptz", index: true),
      Webhookdb::Services::Column.new(:date, "date", index: true),
      Webhookdb::Services::Column.new(:route_id, "text", index: true),
      Webhookdb::Services::Column.new(:updated_at, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    Sequel[self.table_sym][:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _prepare_for_insert(body, **_kwargs)
    return nil unless Webhookdb::Increase.contains_desired_object(body, "transaction")
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      account_id: obj_of_interest.fetch("account_id"),
      amount: obj_of_interest.fetch("amount"),
      created_at: obj_of_interest.fetch("created_at"),
      # date is a legacy field that is not documented in the API,
      # but is still sent with transactions as of April 2022.
      # We need to support the v1 schema, but do not want to depend
      # on Increase continuing to send a transaction resource 'date' field.
      date: obj_of_interest.fetch("created_at").in_time_zone("UTC").to_date,
      increase_id: obj_of_interest.fetch("id"),
      route_id: obj_of_interest.fetch("route_id"),
      updated_at: updated,
    }
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/transactions"
  end
end
