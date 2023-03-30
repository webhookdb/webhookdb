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
    return Webhookdb::Replicator::Column.new(:mya_property_id, INTEGER)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:name, TEXT, data_key: ["Property", "name"]),
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_password, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_sub_id, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def upsert_webhook(request, **kw)
    return if request.path == GET_SUB_PROPERTIES_PATH
    super
  end

  def synchronous_processing_response_body(upserted:, request:)
    case request.path
      when CREATE_PROPERTY_PATH
        return {
          "success" => true,
          "ota_property_id" => upserted.fetch(:ota_property_id),
          "ota_property_password" => upserted.fetch(:ota_property_password),
        }.to_json
      when GET_SUB_PROPERTIES_PATH
        ota_property_id = request.body.fetch("ota_property_id")
        sub_property_data = self.admin_dataset do |ds|
          ds.where(ota_property_id:).select(:name, :ota_property_sub_id).map do |sub_prop|
            {
              "ota_property_sub_id" => sub_prop[:ota_property_sub_id],
              "title" => sub_prop[:name],
            }
          end
        end
        return {
          "success" => true,
          "SubProperties" => sub_property_data,
        }.to_json
    end
  end
end
