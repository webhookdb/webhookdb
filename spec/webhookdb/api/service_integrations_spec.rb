# frozen_string_literal: true

require "webhookdb/api/service_integrations"

RSpec.describe Webhookdb::API::ServiceIntegrations, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  describe "POST /v1/service_integrations/:opaque_id" do
    it "publishes an event with the data for the webhook", :async do
      sint = Webhookdb::Fixtures.service_integration.create(opaque_id: "xyz")
      header "X-My-Test", "abc"
      expect do
        post "/v1/service_integrations/xyz", foo: 1
        expect(last_response).to have_status(202)
      end.to publish("webhookdb.serviceintegration.webhook").with_payload(
        match_array(
          [
            sint.id,
            hash_including(
              "headers" => hash_including("X-My-Test" => "abc"),
              "body" => {"foo" => 1},
            ),
          ],
        ),
      )
    end

    it "returns the response from the configured service" do
      Webhookdb::Services::Fake.webhook_response_body = "<x></x>"
      Webhookdb::Services::Fake.webhook_response_content_type = "text/xml"

      Webhookdb::Fixtures.service_integration.create(opaque_id: "xyz")

      post "/v1/service_integrations/xyz"

      expect(last_response).to have_status(202)
      expect(last_response.body).to eq("<x></x>")
      expect(last_response.headers).to include("Content-Type" => "text/xml")
    end

    it "400s if there is no active service integration" do
      Webhookdb::Fixtures.service_integration.create(opaque_id: "xyz").soft_delete
      header "X-My-Test", "abc"
      post "/v1/service_integrations/xyz", foo: 1
      expect(last_response).to have_status(400)
    end
  end
end
