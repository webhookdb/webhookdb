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
    return Webhookdb::Services::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Services::Column.new(
        :created_at,
        TIMESTAMP,
        data_key: "created_at",
        optional: true,
        index: true,
      ),
      # date is a legacy field that is not documented in the API,
      # but is still sent with transactions as of April 2022.
      # We need to support the v1 schema, but do not want to depend
      # on Increase continuing to send a transaction resource 'date' field.
      Webhookdb::Services::Column.new(
        :date,
        DATE,
        index: true,
        data_key: "created_at",
        optional: true,
        converter: Webhookdb::Services::Column::CONV_TO_UTC_DATE,
      ),
      Webhookdb::Services::Column.new(:route_id, TEXT, index: true),
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

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _resource_and_event(request)
    return self._find_resource_and_event(request.body, "transaction")
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/transactions"
  end
end
