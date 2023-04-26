# frozen_string_literal: true

class Webhookdb::Replicator::LimeTripV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "lime_trip_v1",
      ctor: ->(sint) { Webhookdb::Replicator::LimeTripV1.new(sint) },
      feature_roles: ["indirect"],
      resource_name_singular: "Lime Trip",
      dependency_descriptor: Webhookdb::Replicator::LimeMaasV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(
      :lime_id,
      UUID,
      data_key: "path",
      converter: Webhookdb::Replicator::Column.converter_from_regex(/(#{Webhookdb::Id::UUID_RE})/),
    )
  end

  def _denormalized_columns
    opts = {skip_nil: true, optional: true}
    return [
      Webhookdb::Replicator::Column.new(:user_id, UUID, data_key: "user_id", index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT, data_key: "status"),
      Webhookdb::Replicator::Column.new(:rate_plan_id, UUID, data_key: "rate_plan_id"),
      Webhookdb::Replicator::Column.new(:vehicle_id, TEXT, data_key: "vehicle_id"),
      Webhookdb::Replicator::Column.new(:started_at, TIMESTAMP, data_key: "started_at", index: true),
      Webhookdb::Replicator::Column.new(:updated_at, TIMESTAMP, data_key: "updated_at", index: true),
      Webhookdb::Replicator::Column.new(:completed_at, TIMESTAMP, data_key: "completed_at", index: true, optional: true),
      Webhookdb::Replicator::Column.new(:start_location_lat, DECIMAL, data_key: "completed_at", index: true, optional: true),
      Webhookdb::Replicator::Column.new(:start_location_lng, DECIMAL, data_key: "completed_at", index: true, optional: true),
      Webhookdb::Replicator::Column.new(:end_location_lat, DECIMAL, data_key: "completed_at", index: true, optional: true),
      Webhookdb::Replicator::Column.new(:end_location_lng, DECIMAL, data_key: "completed_at", index: true, optional: true),
    ]
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    h = super
    # h[:deleted_at] = Time.now if request.method == "DELETE"
    return h
  end

  # def _fetch_enrichment(_resource, _event, request)
  #   return request.as_json
  # end

  # def synchronous_processing_response_body(upserted:, request:)
  #   resp = {"listing_id" => upserted.fetch(:listing_id)}
  #   return resp.to_json if request.method == "DELETE"
  #   resp.merge!(request.body)
  #   return resp.to_json
  # end
end
