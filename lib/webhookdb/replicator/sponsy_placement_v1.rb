# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsyPlacementV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_placement_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Sponsy Placement",
      dependency_descriptor: Webhookdb::Replicator::SponsyPublicationV1.descriptor,
      supports_backfill: true,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:publication_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:slug, TEXT),
      Webhookdb::Replicator::Column.new(:color, TEXT),
      Webhookdb::Replicator::Column.new(:order, INTEGER),
    ].concat(self._ts_columns)
  end

  def _backfillers(publication_ids: nil, publication_slugs: nil)
    return self._publication_backfillers("/placements", publication_ids:, publication_slugs:)
  end
end
