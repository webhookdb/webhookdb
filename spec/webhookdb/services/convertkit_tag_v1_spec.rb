# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::ConvertkitTagV1, :db do
  before(:each) do
    stub_request(:get, %r{^https://api\.convertkit\.com/v3/tags/\d+/subscriptions}).
      to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          total_subscriptions: 2,
          page: 1,
          total_pages: 1,
          subscriptions: [],
        }.to_json,
      )
    allow(Kernel).to receive(:sleep)
  end

  it_behaves_like "a service implementation", "convertkit_tag_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":2641288,
          "name":"Example Tag",
          "created_at":"2021-09-22T20:40:49.000Z"
        }
      J
    end
    let(:expected_data) { body }
  end

  it_behaves_like "a service implementation that can backfill", "convertkit_tag_v1" do
    let(:page1_response) do
      <<~R
        {
          "tags": [
            {
              "id": 1,
              "name": "House Stark",
              "created_at": "2016-02-28T08:07:00Z"
            },
            {
              "id": 2,
              "name": "House Lannister",
              "created_at": "2016-02-28T08:07:00Z"
            }
          ]
        }
      R
    end
    let(:expected_items_count) { 2 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
          to_return(status: 500, body: "ugh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_tag_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req)
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_tag_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "calculate_create_state_machine" do
      it "returns a backfill state" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          complete: false,
          output: match("we need to use the API to make requests"),
        )
      end
    end
    describe "calculate_backfill_state_machine" do
      it "it asks for backfill secret" do
        sint.backfill_key = "api_k3y"
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("Paste or type"),
          prompt_is_secret: true,
          post_to_url: "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret",
          complete: false,
          output: match("we need to use the API to make requests"),
        )
      end
      it "returns a complete step if it has a secret" do
        sint.backfill_secret = "api_s3cr3t"
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: false,
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("start backfilling your ConvertKit Tags now"),
        )
      end
    end
  end

  it_behaves_like "a service implementation that uses enrichments", "convertkit_tag_v1" do
    let(:enrichment_tables) { [] }
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":2641288,
          "name":"Example Tag",
          "created_at":"2021-09-21T20:40:49.000Z"
        }
      J
    end
    let(:analytics_body) do
      <<~R
        {
          "total_subscriptions": 2,
          "page": 1,
          "total_pages": 1,
          "subscriptions": []
        }
      R
    end

    def stub_service_request
      return stub_request(:get, "https://api.convertkit.com/v3/tags/2641288/subscriptions?api_secret=").
          to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: analytics_body)
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/tags/2641288/subscriptions?api_secret=").
          to_return(status: 500, body: "ahh")
    end

    def assert_is_enriched(row)
      return row[:total_subscribers] == 2
    end

    def assert_enrichment_after_insert(_db)
      # we are not putting enriched data in a separate table, so this can just return true
      return true
    end
  end

  describe "_fetch_enrichment" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_tag_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":2641288,
          "name":"Example Tag",
          "created_at":"2021-09-22T20:40:49.000Z"
        }
      J
    end

    it "sleeps to avoid rate limiting" do
      Webhookdb::Convertkit.sleep_seconds = 1.2
      expect(Kernel).to receive(:sleep).with(1.2)
      svc._fetch_enrichment(body)
    end
  end
end
