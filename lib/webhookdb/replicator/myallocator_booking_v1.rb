# frozen_string_literal: true

require "webhookdb/replicator/myallocator_v1_mixin"

class Webhookdb::Replicator::MyallocatorBookingV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MyallocatorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_booking_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorBookingV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Booking",
      dependency_descriptor: Webhookdb::Replicator::MyallocatorRootV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:booking_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:mya_property_id, INTEGER),
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT),
      Webhookdb::Replicator::Column.new(:ota_property_sub_id, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _upsert_webhook(request)
    return if GET_BOOKING_PATHS.include?(request.path)
    super
  end

  def synchronous_processing_response_body(request:, **)
    case request.path
      when /BookingCreate/
        return "{}"
      when /GetBookingId/
        booking_id = request.body.fetch("booking_id")
        booking = self.admin_dataset { |booking_ds| booking_ds[booking_id:] }
        return {"success" => true, "Booking" => booking[:data]}.to_json
      when /GetBookingList/
        bookings = self.admin_dataset do |booking_ds|
          match_id_conditions = [
            [:mya_property_id, request.body.fetch("mya_property_id")],
            [:ota_property_id, request.body.fetch("ota_property_id")],
            [:ota_property_sub_id, request.body.fetch("ota_property_sub_id")],
          ]
          filtered = booking_ds.where(match_id_conditions)
          ota_booking_version = request.body.fetch("ota_booking_version")
          filtered = filtered.where { row_updated_at > Time.parse(ota_booking_version) } unless ota_booking_version.nil?
          filtered.select(:booking_id)
        end
        return {"success" => true, "Bookings" => bookings.map { |row| {"booking_id" => row[:booking_id]} }}.to_json
    end
    # TODO: better error handling
    raise "invalid path"
  end
end
