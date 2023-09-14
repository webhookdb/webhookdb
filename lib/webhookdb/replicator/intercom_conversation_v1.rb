# frozen_string_literal: true

require "webhookdb/intercom"
require "webhookdb/replicator/intercom_v1_mixin"

class Webhookdb::Replicator::IntercomConversationV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IntercomV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "intercom_conversation_v1",
      ctor: self,
      feature_roles: ["intercom"],
      resource_name_singular: "Intercom Conversation",
      dependency_descriptor: Webhookdb::Replicator::IntercomMarketplaceRootV1.descriptor,
      supports_backfill: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:intercom_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:title, TEXT),
      Webhookdb::Replicator::Column.new(:state, TEXT),
      Webhookdb::Replicator::Column.new(:open, BOOLEAN),
      Webhookdb::Replicator::Column.new(:read, BOOLEAN),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, converter: :tsat),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, converter: :tsat),
    ]
  end

  def _mixin_backfill_url = "https://api.intercom.io/conversations"
end
