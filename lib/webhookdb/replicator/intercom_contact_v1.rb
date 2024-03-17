# frozen_string_literal: true

require "webhookdb/intercom"
require "webhookdb/replicator/intercom_v1_mixin"

class Webhookdb::Replicator::IntercomContactV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IntercomV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "intercom_contact_v1",
      ctor: self,
      feature_roles: ["intercom"],
      resource_name_singular: "Intercom Contact",
      dependency_descriptor: Webhookdb::Replicator::IntercomMarketplaceRootV1.descriptor,
      supports_backfill: true,
      api_docs_url: "https://developers.intercom.com/docs/references/rest-api/api.intercom.io/Contacts/",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:intercom_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      # All of these fields are missing on delete.
      # We merge the deleted info into an existing one when handling the upsert.
      Webhookdb::Replicator::Column.new(:external_id, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:email, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(
        :created_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true,
      ),
      Webhookdb::Replicator::Column.new(
        :updated_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true,
      ),
      # This is set in the contact.deleted webhook
      Webhookdb::Replicator::Column.new(:deleted_at, TIMESTAMP, optional: true),
    ]
  end

  def _mixin_backfill_url = "https://api.intercom.io/contacts"

  def _resource_and_event(request)
    resource, event = super
    return resource, nil if event.nil?
    if event.fetch("topic") == "contact.deleted"
      resource["updated_at"] = Time.now
      resource["deleted_at"] = Time.now
    end
    return resource, event
  end

  def _upsert_update_expr(inserting, enrichment: nil)
    result = super
    is_deleting = inserting[:deleted_at] && !inserting[:created_at]
    if is_deleting
      data_col = Sequel[self.service_integration.table_name.to_sym][:data]
      result = {
        deleted_at: result.fetch(:deleted_at),
        updated_at: result.fetch(:updated_at),
        data: Sequel.join([data_col, Sequel.lit('\'{"deleted":true}\'::jsonb')]),
      }
    end
    return result
  end
end
