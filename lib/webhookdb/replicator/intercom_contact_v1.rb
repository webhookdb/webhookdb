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
      Webhookdb::Replicator::Column.new(:external_id, TEXT),
      Webhookdb::Replicator::Column.new(:email, TEXT),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, converter: QUESTIONABLE_TIMESTAMP),
    ]
  end

  def _mixin_backfill_url = "https://api.intercom.io/contacts"
end
