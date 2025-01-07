# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::ErrorIcalendarFetch < Webhookdb::Message::Template
  def self.fixtured(_recipient)
    sint = Webhookdb::Fixtures.service_integration.create
    return self.new(sint, "calendar123",
                    response_status: 403, request_url: "/foo", request_method: "GET", response_body: "hi",)
  end

  attr_accessor :service_integration

  def initialize(service_integration, external_calendar_id, request_url:, request_method:, response_status:,
    response_body:)
    @service_integration = service_integration
    @external_calendar_id = external_calendar_id
    @request_url = request_url
    @request_method = request_method
    @response_status = response_status
    @response_body = response_body
    super()
  end

  def signature
    return "msg-#{self.full_template_name}-sint:#{@service_integration.id}-eid:#{@external_calendar_id}"
  end

  def template_folder = "errors"
  def template_name = "icalendar_fetch"

  def liquid_drops
    return super.merge(
      service_name: @service_integration.service_name,
      opaque_id: @service_integration.opaque_id,
      request_method: @request_method,
      request_url: @request_url,
      response_status: @response_status,
      response_body: @response_body,
      external_calendar_id: @external_calendar_id,
      webhook_endpoint: @service_integration.replicator.webhook_endpoint,
      org_name: @service_integration.organization.name,
      org_key: @service_integration.organization.key,
    )
  end
end
