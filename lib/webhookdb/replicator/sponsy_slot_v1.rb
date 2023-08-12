# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsySlotV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_slot_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Sponsy Slot",
      dependency_descriptor: Webhookdb::Replicator::SponsyPublicationV1.descriptor,
      supports_backfill: true,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:publication_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:date, DATE, index: true),
      Webhookdb::Replicator::Column.new(:notes, TEXT),
      Webhookdb::Replicator::Column.new(
        :customer_id, TEXT, data_key: ["customer", "id"], optional: true, index: true,
      ),
      Webhookdb::Replicator::Column.new(
        :placement_id, TEXT, data_key: ["placement", "id"], optional: true, index: true,
      ),
      Webhookdb::Replicator::Column.new(
        :status_id, TEXT, data_key: ["status", "id"], optional: true, index: true,
      ),
    ].concat(self._ts_columns)
  end

  def _backfillers(publication_ids: nil, publication_slugs: nil)
    return self._publication_backfillers("/slots", publication_ids:, publication_slugs:)
  end
end
