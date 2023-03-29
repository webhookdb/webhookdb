# frozen_string_literal: true

require "webhookdb/replicator/myallocator_v1_mixin"

class Webhookdb::Replicator::MyallocatorRoomV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MyallocatorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_room_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorRoomV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Room",
      dependency_descriptor: Webhookdb::Replicator::MyallocatorPropertyV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:mya_room_id, INTEGER)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:mya_property_id, INTEGER),
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_sub_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_password, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
      # these values are required when we respond to a `GetRoomTypes` request
      # with room info, so we denormalize them
      Webhookdb::Replicator::Column.new(:ota_room_id, TEXT, index: true, defaulter: :uuid, optional: true),
      Webhookdb::Replicator::Column.new(:beds, INTEGER),
      Webhookdb::Replicator::Column.new(:dormitory, BOOLEAN),
      Webhookdb::Replicator::Column.new(:label, TEXT),
    ]
  end

  def get_ota_room_id(mya_room_id)
    self.admin_dataset do |ds|
      room = ds[mya_room_id:]
      raise Webhookdb::InvalidPostcondition, "there is no room with myallocator id #{mya_room_id}" if room.nil?
      return room[:ota_room_id]
    end
  end

  def _upsert_webhook(request)
    # Noop if the property doesn't exist, so that we can return an appropriate MyAllocator
    # error response in `synchronous_processing_response_body`.
    property_row = self.get_parent_property_row(request)
    return if property_row.nil?
    # If the OTA creds, i.e. the OTA property ID and Password, are incorrect, then we should
    # noop so that we can return an appropriate MyAllocator error response in
    # `synchronous_processing_response_body`. The exception is `SetupProperty` requests
    # because they never pass in these values at all, according to the documentation.
    return unless self.ota_creds_correct?(property_row,
                                          request,) || [SETUP_PROPERTY_PATH,
                                                        CREATE_PROPERTY_PATH,].include?(request.path)
    property_data = {
      "mya_property_id" => property_row[:mya_property_id],
      "ota_property_id" => property_row[:ota_property_id],
      "ota_property_sub_id" => property_row[:ota_property_sub_id],
      "ota_property_password" => property_row[:ota_property_password],
    }
    room_info = if request.path == CREATE_PROPERTY_PATH
                  request.body.dig("Property", "rooms")
                else
                  request.body["RoomInfo"]
                end
    room_info&.each do |room|
      data = room.merge(property_data)
      # let's not mutate the original request
      new_req = request.dup
      new_req.body = data
      super(new_req)
    end
  end

  def synchronous_processing_response_body(request:, **)
    property_row = self.get_parent_property_row(request)
    return {"success" => false, "errors" => [{"id" => 1154, "msg" => "No such property"}]}.to_json if property_row.nil?
    return {"success" => true}.to_json if request.path == SETUP_PROPERTY_PATH

    return unless request.path == GET_ROOMS_PATH
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
    room_rows = self.admin_dataset do |ds|
      ds.where(mya_property_id: request.body.fetch("mya_property_id")).all
    end
    room_info = room_rows.map do |row|
      # Note that the field names differ between input and output for some reason.
      {
        "ota_room_id" => row[:ota_room_id],
        "title" => row[:label],
        "occupancy" => row[:beds],
        "dorm" => row[:dormitory],
      }
    end
    return {"success" => true, "Rooms" => room_info}.to_json
  end
end
