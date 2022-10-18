# frozen_string_literal: true

require "webhookdb/services/sponsy_v1_mixin"

class Webhookdb::Services::SponsyPlacementV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "sponsy_placement_v1",
      ctor: self,
      feature_roles: ["beta"],
      resource_name_singular: "Sponsy Placement",
      dependency_descriptor: Webhookdb::Services::SponsyPublicationV1.descriptor,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:publication_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:name, TEXT),
      Webhookdb::Services::Column.new(:slug, TEXT),
      Webhookdb::Services::Column.new(:color, TEXT),
      Webhookdb::Services::Column.new(:order, INTEGER),
    ].concat(self._ts_columns)
  end

  def _backfillers
    return self._publication_backfillers("/placements")
  end
end
