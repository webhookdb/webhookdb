# frozen_string_literal: true

require "webhookdb/replicator/front_v1_mixin"

class Webhookdb::Replicator::FrontMessageV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::DBAdapter::ColumnTypes
  include Webhookdb::Replicator::FrontV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "front_message_v1",
      ctor: self,
      feature_roles: ["front"],
      resource_name_singular: "Front Message",
      dependency_descriptor: Webhookdb::Replicator::FrontMarketplaceRootV1.descriptor,
      supports_webhooks: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:front_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:type, TEXT),
      Webhookdb::Replicator::Column.new(:front_conversation_id, TEXT, event_key: ["conversation", "id"]),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, converter: :tsat),
    ]
  end

  def _timestamp_column_name
    return :created_at
  end

  def _resource_and_event(request)
    return request.body.dig("payload", "target", "data"), request.body.fetch("payload")
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end
end
