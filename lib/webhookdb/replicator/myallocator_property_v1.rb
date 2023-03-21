# frozen_string_literal: true

require "webhookdb/replicator/myallocator_v1_mixin"

class Webhookdb::Replicator::MyallocatorPropertyV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MyallocatorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_property_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorPropertyV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Property",
      resource_name_plural: "MyAllocator Properties",
      dependency_descriptor: Webhookdb::Replicator::MyallocatorRootV1.descriptor,
    )
  end

  def _remote_key_column
    # TODO: is this the right choice for remote key
    return Webhookdb::Replicator::Column.new(:mya_property_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_password, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def synchronous_processing_response_body(upserted:, **)
    return {success: true, ota_property_id: upserted.fetch(:ota_property_id)}.to_json
  end
end
