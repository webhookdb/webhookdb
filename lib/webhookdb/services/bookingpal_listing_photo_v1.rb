# frozen_string_literal: true

require "webhookdb/services/bookingpal_v1_mixin"

class Webhookdb::Services::BookingpalListingPhotoV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::BookingpalV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "bookingpal_listing_photo_v1",
      ctor: ->(sint) { Webhookdb::Services::BookingpalListingPhotoV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "BookingPal Listing Photo",
      dependency_descriptor: Webhookdb::Services::BookingpalListingV1.descriptor,
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(
      :photo_id,
      INTEGER,
      data_key: "path",
      from_enrichment: true,
      converter: Webhookdb::Services::Column.converter_int_or_sequence_from_regex(%r{/v2/listing_photos/(\d+)}),
    )
  end

  def _denormalized_columns
    return [
      # Listing ID is present on POST but missing on DELETE.
      Webhookdb::Services::Column.new(
        :listing_id, INTEGER, data_key: "listing_id", optional: true, skip_nil: true,
      ),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
      Webhookdb::Services::Column.new(:deleted_at, TIMESTAMP, defaulter: DEFAULTER_DELETED_AT, optional: true),
    ]
  end

  def requires_sequence?
    return true
  end

  def _fetch_enrichment(_resource, _event, request)
    return request.as_json
  end

  def synchronous_processing_response_body(upserted:, request:)
    photo_id = upserted.fetch(:photo_id)
    resp = {"photo_id" => photo_id}
    if request.method == "DELETE"
      listing_id = self.admin_dataset do |ds|
        ds.where(photo_id:).select(:listing_id).single_value
      end
      resp["listing_id"] = listing_id
    else
      resp.merge!(request.body)
    end
    return resp.to_json
  end
end
