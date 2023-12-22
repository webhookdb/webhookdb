# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/replicator/increase_v1_mixin"

class Webhookdb::Replicator::IncreaseACHTransferV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_ach_transfer_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IncreaseACHTransferV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Increase ACH Transfer",
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
      Webhookdb::Replicator::Column.new(:account_number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(
        :created_at,
        TIMESTAMP,
        data_key: "created_at",
        index: true,
      ),
      Webhookdb::Replicator::Column.new(:routing_number, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:transaction_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :updated_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        index: true,
      ),
    ]
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    # created_at is marked required, but to skip on nil.
    # This will preserve its existing value when we update the webhook.
    resource["created_at"] = nil if event&.fetch("event") == "updated"
    return super
  end

  def _upsert_update_expr(inserting, enrichment: nil)
    update = super
    update[:data] = Sequel.lit("#{self.service_integration.table_name}.data || excluded.data")
    return update
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _resource_and_event(request)
    resource, event = self._find_resource_and_event(request.body, "ach_transfer")
    return nil, nil if (resource && resource["type"]) == "inbound_ach_transfer"
    return resource, event
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/transfers/achs"
  end
end
