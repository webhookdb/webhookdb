# frozen_string_literal: true

require "webhookdb/services/sponsy_v1_mixin"

class Webhookdb::Services::SponsySlotV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "sponsy_slot_v1",
      ctor: self,
      feature_roles: ["beta"],
      resource_name_singular: "Sponsy Slot",
      dependency_descriptor: Webhookdb::Services::SponsyPublicationV1.descriptor,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:publication_id, TEXT, index: true),
      Webhookdb::Services::Column.new(:date, DATE, index: true),
      Webhookdb::Services::Column.new(:notes, TEXT),
      Webhookdb::Services::Column.new(
        :customer_id, TEXT, data_key: ["customer", "id"], optional: true, index: true,
      ),
      Webhookdb::Services::Column.new(
        :placement_id, TEXT, data_key: ["placement", "id"], optional: true, index: true,
      ),
      Webhookdb::Services::Column.new(
        :status_id, TEXT, data_key: ["status", "id"], optional: true, index: true,
      ),
    ].concat(self._ts_columns)
  end

  def _backfillers
    return self._publication_backfillers("/slots")
  end
end
