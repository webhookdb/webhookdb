# frozen_string_literal: true

require "webhookdb/replicator/myallocator_v1_mixin"

class Webhookdb::Replicator::MyallocatorRatePlanV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::MyallocatorV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_rate_plan_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorRatePlanV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Rate Plan",
      dependency_descriptor: Webhookdb::Replicator::MyallocatorRoomV1.descriptor,
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: ->(_, resource:, **_) { "#{resource.fetch('mya_room_id')}-#{resource.fetch('mya_rate_id')}" },
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
      # These `label_private` and `label_public` fields get denormalized because `GetRatePlans`
      # requests expect us to return a text value called 'title' and it's ambiguous which of these
      # values we're supposed to return.
      Webhookdb::Replicator::Column.new(:label_private, TEXT),
      Webhookdb::Replicator::Column.new(:label_public, TEXT),
      Webhookdb::Replicator::Column.new(:mya_property_id, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:mya_rate_id, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:mya_room_id, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:ota_property_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:ota_property_sub_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:ota_property_password, TEXT),
      # TODO: For cases where the MYA rate id is 0 (i.e. the rate is the default for the room), do we
      #  want to make the ota_rate_id "0"?
      Webhookdb::Replicator::Column.new(:ota_rate_id, TEXT, defaulter: :uuid, optional: true),
      Webhookdb::Replicator::Column.new(:ota_room_id, TEXT),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
    ]
  end

  def _upsert_webhook(request)
    # Noop if the property doesn't exist, so that we can return an appropriate MyAllocator
    # error response in `synchronous_processing_response_body`.
    property_row = self.get_parent_property_row(request)
    return if property_row.nil?
    # If the OTA creds, i.e. the OTA property ID and Password, are incorrect, then we should
    # noop so that we can return an appropriate MyAllocator error response in
    # `synchronous_processing_response_body`.
    return unless self.ota_creds_correct?(property_row, request)
    # We should only be able to upsert to the rate plan table through the `CreateProperty`
    # endpoint, so we can noop for all other paths. This also means that the request shape
    # will always be the same
    return unless request.path == CREATE_PROPERTY_PATH
    property_data = {
      "mya_property_id" => request.body.fetch("mya_property_id"),
      "ota_property_id" => request.body.fetch("ota_property_id"),
      "ota_property_sub_id" => request.body.fetch("ota_property_sub_id"),
      "ota_property_password" => request.body.fetch("ota_property_password"),
    }
    room_svc = self.get_dependency_replicator("myallocator_room_v1")
    rooms = request.body.dig("Property", "rooms")
    # The `CreateProperty` request has an array of rooms, and each of those rooms has
    # an array of rate plans. We need to flatten this into a list of requests that we
    # can individually upsert.
    synthesized_requests = []
    rooms.each do |room|
      mya_room_id = room.fetch("mya_room_id")
      ota_room_id = room_svc.get_ota_room_id(mya_room_id)

      property_and_room_data = property_data.merge("mya_room_id" => mya_room_id, "ota_room_id" => ota_room_id)
      rate_plans = room.fetch("rateplans", nil)
      rate_plans&.each do |rate_plan|
        request_body = rate_plan.merge(property_and_room_data)
        # let's not mutate the original request
        new_request = request.dup
        new_request.body = request_body
        synthesized_requests.append(new_request)
      end
    end
    synthesized_requests.each { |req| super(req) }
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
    if request.path == GET_RATE_PLANS_PATH
      rate_plan_rows = self.admin_dataset { |ds| ds.where(mya_property_id: request.body.fetch("mya_property_id")).all }
      rate_plan_info = rate_plan_rows.map do |row|
        {
          "ota_room_id" => row[:ota_room_id],
          "ota_rate_id" => row[:ota_rate_id],
          "title" => row[:label_public],
        }
      end
      return {"success" => true, "RatePlans" => rate_plan_info}.to_json
    end
  end
end
