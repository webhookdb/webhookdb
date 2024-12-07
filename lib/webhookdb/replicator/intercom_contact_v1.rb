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
      Webhookdb::Replicator::Column.new(:external_id, TEXT, optional: true, index: true),
      Webhookdb::Replicator::Column.new(:email, TEXT, optional: true, index: true),
      Webhookdb::Replicator::Column.new(
        :created_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true, index: true,
      ),
      Webhookdb::Replicator::Column.new(
        :updated_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP, optional: true, index: true,
      ),
      # This is set in the contact.deleted webhook
      Webhookdb::Replicator::Column.new(:deleted_at, TIMESTAMP, optional: true),
      # This is set in the contact.archived webhook
      Webhookdb::Replicator::Column.new(:archived_at, TIMESTAMP, optional: true),
    ]
  end

  def _mixin_backfill_url = "https://api.intercom.io/contacts"
  def _mixin_backfill_hashkey = "data"

  def _resource_and_event(request)
    resource, event = super
    return resource, nil if event.nil?
    # noinspection RubyCaseWithoutElseBlockInspection
    case event.fetch("topic")
        when "contact.deleted"
          resource["updated_at"] = Time.now
          resource["deleted_at"] = Time.now
        when "contact.archived"
          resource["updated_at"] = Time.now
          resource["archived_at"] = Time.now
        when "contact.unsubscribed"
          resource = resource.fetch("contact")
      end
    return resource, event
  end

  def _upsert_update_expr(inserting, enrichment: nil)
    full_update = super
    # In the case of a delete or archive, update the deleted_at/archived_at field,
    # and merge 'deleted' or 'archived' into the :data field.
    if inserting[:deleted_at]
      status_key = :deleted_at
      status_field = "deleted"
    elsif inserting[:archived_at]
      status_key = :archived_at
      status_field = "archived"
    else
      return full_update
    end
    result = {updated_at: full_update.fetch(:updated_at)}
    result[status_key] = full_update.fetch(status_key)
    data_col = Sequel[self.service_integration.table_name.to_sym][:data]
    result[:data] = Sequel.join([data_col, Sequel.lit("'{\"#{status_field}\":true}'::jsonb")])
    return result
  end
end
