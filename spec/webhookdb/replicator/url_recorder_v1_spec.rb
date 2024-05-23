# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::UrlRecorderV1, :db do
  it_behaves_like "a replicator", supports_row_diff: false do
    let(:request_path) { "/foo" }
    let(:request_method) { "GET" }
    let(:request_headers) { {"Accept" => "*"} }
    let(:rack_request) do
      Rack::Request.new(
        {
          "PATH_INFO" => "/mypath",
          "QUERY_STRING" => "z=2",
          "rack.url_scheme" => "http",
          "REMOTE_ADDR" => "1.2.9.8",
          "REMOTE_HOST" => "localhost",
          "REQUEST_METHOD" => "GET",
          "SCRIPT_NAME" => "/scriptname",
          "SERVER_NAME" => "localhost",
          "SERVER_PORT" => "9292",
          "HTTP_USER_AGENT" => "Mozilla/5.0",
          "REQUEST_PATH" => "/reqpath",
        },
      )
    end

    let(:body) { {"x" => 1} }
    let(:expected_row) do
      include(
        unique_id: 1,
        data: be_empty,
        request_method: "GET",
        path: "/scriptname/mypath",
        full_url: "http://localhost:9292/scriptname/mypath?z=2",
        user_agent: "Mozilla/5.0",
        ip: "1.2.9.8",
        parsed_query: eq({"z" => "2"}),
        parsed_body: eq({"x" => 1}),
        raw_body: nil,
      )
    end

    it "handles a string body" do
      svc.create_table
      rack_request.set_header("rack.input", Webhookdb::SpecHelpers::Service::Rewindable.new(""))
      upsert_webhook(svc, body: "unparseable")
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(parsed_body: nil, raw_body: "unparseable"),
      )
    end

    it "uses the form body if available" do
      svc.create_table
      rr = rack_request
      rr.set_header("rack.input", Webhookdb::SpecHelpers::Service::Rewindable.new("x=y"))
      rr.set_header("CONTENT_TYPE", "application/x-www-form-urlencoded")
      upsert_webhook(svc, body: "x=1")
      expect(svc.readonly_dataset(&:all)).to contain_exactly(
        include(parsed_body: {"x" => "y"}, raw_body: nil),
      )
    end
  end

  # describe "webhook_response" do
  #   let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: described_class.descriptor.name) }
  #   let(:svc) { Webhookdb::Replicator.create(sint) }
  #
  #   it "returns a redirect if the api url starts with http" do
  #     sint.update(api_url: "http://foo.bar")
  #     req = fake_request
  #     expect(svc.webhook_response(req)).to have_attributes(
  #       status: 302,
  #       body: "",
  #       headers: include("Location" => "http://foo.bar"),
  #     )
  #   end
  #
  #   it "returns a redirect if the api url starts with https" do
  #     sint.update(api_url: "https://foo.bar")
  #     req = fake_request
  #     expect(svc.webhook_response(req)).to have_attributes(
  #       status: 302,
  #       body: "",
  #       headers: include("Location" => "https://foo.bar"),
  #     )
  #   end
  #
  #   it "uses the given html if the api_url starts with a doctype" do
  #     sint.update(api_url: "<!DOCTYPE html>\n<html lang='en-us'><body>hi</body></html>")
  #     req = fake_request
  #     expect(svc.webhook_response(req)).to have_attributes(
  #       status: 200,
  #       body: sint.api_url,
  #       headers: include("Content-Type" => "text/html"),
  #     )
  #   end
  #
  #   it "uses the given html if the api_url starts with an html element" do
  #     sint.update(api_url: "<html lang='en-us'><body>hi</body></html>")
  #     req = fake_request
  #     expect(svc.webhook_response(req)).to have_attributes(
  #       status: 200,
  #       body: sint.api_url,
  #       headers: include("Content-Type" => "text/html"),
  #     )
  #   end
  #
  #   it "renders the api_url in an HTML template otherwise" do
  #     sint.update(api_url: "<p>thanks!</p>")
  #     req = fake_request
  #     expect(svc.webhook_response(req)).to have_attributes(
  #       status: 200,
  #       body: include('<div class="layout">').and(include("<p>thanks!</p>")),
  #       headers: include("Content-Type" => "text/html"),
  #     )
  #   end
  # end
  #
  # describe "state machine calculation" do
  #   let(:sint) do
  #     Webhookdb::Fixtures.service_integration.create(service_name: described_class.descriptor.name, api_url: "")
  #   end
  #   let(:svc) { Webhookdb::Replicator.create(sint) }
  #
  #   describe "calculate_webhook_state_machine" do
  #     it "asks for the api url" do
  #       sm = svc.calculate_webhook_state_machine
  #       expect(sm).to have_attributes(
  #         needs_input: true,
  #         prompt: "Paste or type your URL, HTML, or text here:",
  #         prompt_is_secret: false,
  #         post_to_url: end_with("/transition/api_url"),
  #         complete: false,
  #         output: match("they can either be redirected"),
  #       )
  #     end
  #
  #     it "confirms reciept of api url, returns org database info" do
  #       sint.api_url = "hello"
  #       sm = svc.calculate_webhook_state_machine
  #       expect(sm).to have_attributes(
  #         needs_input: false,
  #         complete: true,
  #         output: match(/Every visit to/),
  #       )
  #     end
  #   end
  # end
end
