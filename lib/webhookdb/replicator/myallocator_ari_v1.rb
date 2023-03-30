# frozen_string_literal: true

require "webhookdb/replicator/myallocator_v1_mixin"

class Webhookdb::Replicator::MyallocatorAriV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MyallocatorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_ari_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorAriV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Inventory",
      resource_name_plural: "MyAllocator Inventory",
      dependency_descriptor: Webhookdb::Replicator::MyallocatorPropertyV1.descriptor,
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda { |_, resource:, **_|
            "#{resource.fetch('ota_room_id')}-#{resource.fetch('ota_rate_id')}-#{resource.fetch('date')}"
          },
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(
      :compound_identity,
      TEXT,
      data_key: "<compound key, see converter>",
      index: true,
      converter: CONV_REMOTE_KEY,
      optional: true, # This is done via the converter, data_key never exists
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:mya_property_id, INTEGER),
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_sub_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_rate_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_room_id, TEXT),
      Webhookdb::Replicator::Column.new(:date, DATE, optional: true),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _upsert_webhook(request)
    # Noop if the property doesn't exist, so that we can return an appropriate MyAllocator
    # error response in `synchronous_processing_response_body`.
    property_row = self.get_parent_property_row(request)
    return if property_row.nil?
    return unless self.ota_creds_correct?(property_row, request)
    property_data = {
      "mya_property_id" => request.body.fetch("mya_property_id"),
      "ota_property_id" => request.body.fetch("ota_property_id"),
      "ota_property_sub_id" => request.body.fetch("ota_property_sub_id"),
    }
    inventory_info = request.body.fetch("Inventory")
    inventory_info&.each do |inventory|
      ari_data = inventory.except("start_date", "end_date")
      start_date = Date.parse(inventory.fetch("start_date"))
      end_date = Date.parse(inventory.fetch("end_date"))

      (start_date..end_date).each do |date|
        aggregated_data = {"date" => date}.merge(ari_data, property_data)
        # let's not mutate the original request
        new_req = request.dup
        new_req.body = aggregated_data
        super(new_req)
      end
    end
  end

  def synchronous_processing_response_body(request:, **)
    property_row = self.get_parent_property_row(request)
    return {"success" => false, "errors" => [{"id" => 1154, "msg" => "No such property"}]}.to_json if property_row.nil?
    unless self.ota_creds_correct?(property_row, request)
      return {
        "success" => false,
        "errors" => [
          {
            "id" => 1001,
            "msg" => "Invalid OTA creds for property",
          },
        ],
      }.to_json
    end
    return {"success" => true}.to_json
  end
end
