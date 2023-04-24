# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsyStatusV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_status_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Sponsy Status",
      resource_name_plural: "Sponsy Statuses",
      dependency_descriptor: Webhookdb::Replicator::SponsyPublicationV1.descriptor,
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

  def _backfillers
    return self._publication_backfillers("/status")
  end
end
