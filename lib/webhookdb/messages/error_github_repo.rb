# frozen_string_literal: true

require "webhookdb/message/template"

class Webhookdb::Messages::ErrorGithubRepo < Webhookdb::Message::Template
  def self.fixtured(_recipient)
    sint = Webhookdb::Fixtures.service_integration.create
    return self.new(
      sint,
      response_status: 401,
      request_url: "https://api.github.com/repos/lithictech/webhookdb-api/events",
      request_method: "GET",
      response_body: '{"message":"Bad credentials","documentation_url":"https://docs.github.com/rest"}',
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
    return "msg-#{self.full_template_name}-sint:#{@service_integration.id}-st:#{@response_status}"
  end

  def template_folder = "errors"
  def template_name = "github_repo"

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
