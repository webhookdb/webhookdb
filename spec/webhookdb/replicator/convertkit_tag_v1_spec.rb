# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::ConvertkitTagV1, :db do
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
  end

  it_behaves_like "a replicator", "convertkit_tag_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":2641288,
          "name":"Example Tag",
          "created_at":"2021-09-22T20:40:49.000Z"
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_tag_v1",
        backfill_secret: "bfsek",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_tag_v1",
        backfill_secret: "bfsek_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "tags": []
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek_wrong").
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "convertkit_tag_v1" do
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

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
            to_return(status: 200, body: '{"tags":[]}', headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
          to_return(status: 500, body: "ugh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_tag_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_tag_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_backfill_state_machine" do
      def stub_service_request
        return stub_request(:get, "https://api.convertkit.com/v3/tags?api_secret=bfsek").
            to_return(status: 200, body: "", headers: {})
      end
      it "asks for backfill secret" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("Paste or type"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: match("we need to use the API to make requests"),
        )
      end

      it "returns a complete step if it has a secret" do
        sint.backfill_secret = "bfsek"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("start backfilling your ConvertKit Tags now"),
        )
      end
    end
  end

  it_behaves_like "a replicator that uses enrichments", "convertkit_tag_v1" do
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
    let(:expected_enrichment_data) { JSON.parse(analytics_body) }

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
  end
end
