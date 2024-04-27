# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::ErrorGenericBackfill < Webhookdb::Message::Template
  def self.fixtured(_recipient)
    sint = Webhookdb::Fixtures.service_integration.create
    return self.new(
      sint,
      response_status: 422,
      request_url: "https://whdbtest.signalwire.com/2010-04-01/Accounts/projid/Messages.json",
      request_method: "POST",
      response_body: "Unauthorized",
    )
  end

  def initialize(service_integration, request_url:, request_method:, response_status:, response_body:)
    @service_integration = service_integration
    @request_url = request_url
    @request_method = request_method
    @response_status = response_status
    @response_body = response_body
    super()
  end

  def signature
    # Only alert on the backfill once a day
    return "msg-#{self.full_template_name}-sint:#{@service_integration.id}"
  end

  def template_folder = "errors"
  def template_name = "generic_backfill"

  def liquid_drops
    return super.merge(
      friendly_name: @service_integration.replicator.descriptor.resource_name_singular,
      service_name: @service_integration.service_name,
      opaque_id: @service_integration.opaque_id,
      request_method: @request_method,
      request_url: @request_url,
      response_status: @response_status,
      response_body: @response_body,
    )
  end
end
