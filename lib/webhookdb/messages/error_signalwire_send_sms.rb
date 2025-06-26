# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::ErrorSignalwireSendSms < Webhookdb::Message::Template
  def self.fixtured(_recipient)
    sint = Webhookdb::Fixtures.service_integration.create
    return self.new(
      sint,
      response_status: 422,
      request_url: "https://whdbtest.signalwire.com/api/laml/2010-04-01/Accounts/projid/Messages.json",
      request_method: "POST",
      response_body: {
        code: "21717",
        message: "From must belong to an active campaign.",
        more_info: "https://developer.signalwire.com/compatibility-api/reference/error-codes",
        status: 400,
      }.to_json,
    )
  end

  attr_accessor :service_integration

  def initialize(service_integration, request_url:, request_method:, response_status:, response_body:)
    @service_integration = service_integration
    @request_url = request_url
    @request_method = request_method
    @response_status = response_status
    @response_body = response_body
    super()
  end

  def signature
    return "msg-#{self.full_template_name}-sint:#{@service_integration.id}-req:#{@request_url}"
  end

  def template_folder = "errors"
  def template_name = "signalwire_send_sms"

  def liquid_drops
    return super.merge(
      service_name: @service_integration.service_name,
      opaque_id: @service_integration.opaque_id,
      request_method: @request_method,
      request_url: @request_url,
      response_status: @response_status,
      response_body: @response_body,
    )
  end
end
