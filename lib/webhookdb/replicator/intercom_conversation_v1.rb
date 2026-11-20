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
      api_docs_url: "https://developers.intercom.com/docs/references/rest-api/api.intercom.io/Conversations/",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:intercom_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:title, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:state, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:open, BOOLEAN, optional: true),
      Webhookdb::Replicator::Column.new(:read, BOOLEAN, optional: true),
      Webhookdb::Replicator::Column.new(
        :created_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true, index: true,
      ),
      Webhookdb::Replicator::Column.new(
        :updated_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true, index: true,
      ),
      Webhookdb::Replicator::Column.new(:deleted_at, TIMESTAMP, optional: true, index: true),
    ]
  end

  def _mixin_backfill_url = "https://api.intercom.io/conversations"
  def _mixin_backfill_hashkey = "conversations"

  def _resource_and_event(request)
    resource, event = super
    return resource, nil if event.nil?
    # noinspection RubyCaseWithoutElseBlockInspection
    case event.fetch("topic")
      when "conversation.deleted"
        resource["id"] = resource.fetch("conversation_id")
        resource["updated_at"] = Time.now
        resource["deleted_at"] = Time.now
      when "conversation.contact.attached", "conversation.contact.detached"
        # The convo is in resource['conversation']['model'], and doesn't have a number of fields.
        # This doesn't seem like an important enough event to track for now,
        # unless we start to do it relationally.
        return nil, nil
    end
    return resource, event
  end

  def _upsert_update_expr(inserting, enrichment: nil)
    full_update = super
    # In the case of a delete, update the deleted_at field and merge 'deleted' into the :data field.
    return full_update unless inserting[:deleted_at]
    data_col = Sequel[self.service_integration.table_name.to_sym][:data]
    result = {
      updated_at: full_update.fetch(:updated_at),
      deleted_at: full_update.fetch(:deleted_at),
      data: Sequel.join([data_col, Sequel.lit("'{\"deleted\":true}'::jsonb")]),
    }
    return result
  end
end
