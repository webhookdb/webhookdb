# frozen_string_literal: true

require "webhookdb/services/bookingpal_v1_mixin"

class Webhookdb::Services::BookingpalListingV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::BookingpalV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "bookingpal_listing_v1",
      ctor: ->(sint) { Webhookdb::Services::BookingpalListingV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "BookingPal Listing",
    )
  end

  def requires_sequence?
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(
      :listing_id,
      INTEGER,
      data_key: "path",
      from_enrichment: true,
      converter: Webhookdb::Services::Column.converter_int_or_sequence_from_regex(%r{/v2/listings/(\d+)}),
    )
  end

  def _denormalized_columns
    opts = {skip_nil: true, optional: true}
    return [
      Webhookdb::Services::Column.new(:name, TEXT, data_key: "name", **opts),
      Webhookdb::Services::Column.new(:apt, TEXT, data_key: "apt", **opts),
      Webhookdb::Services::Column.new(:street, TEXT, data_key: "street", **opts),
      Webhookdb::Services::Column.new(:city, TEXT, data_key: "city", **opts),
      Webhookdb::Services::Column.new(:country_code, TEXT, data_key: "country_code", **opts),
      Webhookdb::Services::Column.new(:pm_name, TEXT, data_key: "pm_name", **opts),
      Webhookdb::Services::Column.new(:pm_id, INTEGER, data_key: "pm_id", **opts),
      Webhookdb::Services::Column.new(:row_updated_at, TIMESTAMP, defaulter: :now, optional: true),
      Webhookdb::Services::Column.new(:deleted_at, TIMESTAMP, defaulter: DEFAULTER_DELETED_AT, optional: true),
    ]
  end

  def _fetch_enrichment(_resource, _event, request)
    return request.as_json
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %(In order to authenticate information recieved from BookingPal, we will need a webhook secret.)
      return step.prompting("webhook secret").webhook_secret(self.service_integration)
    end
    step.output = %(WebhookDB will pass this authentication information on to dependents.
    )
    return step.completed
  end

  def synchronous_processing_response_body(upserted:, request:)
    resp = {"listing_id" => upserted.fetch(:listing_id)}
    return resp.to_json if request.method == "DELETE"
    resp.merge!(request.body)
    return {"schema" => resp}.to_json
  end
end
