# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::ConvertkitBroadcastV1, :db do
  before(:each) do
    # Because we enrich, set up a stub response we can always use, without having to worry about mocking everything.
    stub_request(:get, %r{^https://api\.convertkit\.com/v3/broadcasts/\d+/stats}).
      to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {broadcast: {id: 10_000_000, stats: {}}}.to_json,
      )
  end

  it_behaves_like "a replicator", "convertkit_broadcast_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":2641288,
          "name":"Example Broadcast",
          "created_at":"2021-09-22T20:40:49.000Z",
          "subject": "The Meaning of Life"
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_broadcast_v1",
        backfill_secret: "bfsek",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_broadcast_v1",
        backfill_secret: "bfsek_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "broadcasts": []
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek_wrong").
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "convertkit_broadcast_v1" do
    let(:page1_response) do
      <<~R
        {
          "broadcasts": [
            {
              "id": 1,
              "created_at": "2014-02-13T21:45:16.000Z",
              "subject": "Welcome to my Newsletter!"
            },
            {
              "id": 2,
              "created_at": "2014-02-20T11:40:11.000Z",
              "subject": "Check out my latest blog posts!"
            }
          ]
        }
      R
    end
    let(:page2_response) do
      <<~R
        {"broadcasts": []}
      R
    end
    let(:expected_items_count) { 2 }

    def stub_service_requests
      return [
        stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}).
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
          to_return(status: 403, body: "ahhh")
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_backfill_state_machine" do
      def stub_service_request
        return stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
            to_return(status: 200, body: "", headers: {})
      end

      it "asks for backfill secret" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: be_present,
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: match("We've created your"),
        )
      end

      it "returns backfill in progress message" do
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
          output: match("start backfilling your ConvertKit Broadcasts now"),
        )
      end
    end
  end

  it_behaves_like "a replicator that uses enrichments", "convertkit_broadcast_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": 1,
          "subject":"The Broadcast",
          "created_at":"2021-09-21T20:40:49.000Z"
        }
      J
    end
    let(:analytics_body) do
      <<~R
        {
          "broadcast": {
            "id":1,
            "stats":
            {
              "recipients": 82,
              "open_rate": 60.975,
              "click_rate": 23.17,
              "unsubscribes": 9,
              "total_clicks": 15,
              "show_total_clicks": false,
              "status": "completed",
              "progress": 100.0
            }
          }
        }
      R
    end
    let(:expected_enrichment_data) { JSON.parse(analytics_body).dig("broadcast", "stats") }

    def stub_service_request
      return stub_request(:get, "https://api.convertkit.com/v3/broadcasts/1/stats?api_secret=").
          to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: analytics_body,
          )
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/broadcasts/1/stats?api_secret=").
          to_return(status: 503, body: "nope")
    end

    def assert_is_enriched(row)
      expect(row[:recipients]).to eq(82)
      expect(row[:open_rate]).to eq(60.975)
      expect(row[:click_rate]).to eq(23.17)
      expect(row[:unsubscribes]).to eq(9)
      expect(row[:total_clicks]).to eq(15)
      expect(row[:show_total_clicks]).to be(false)
      expect(row[:status]).to eq("completed")
      expect(row[:progress]).to eq(100.0)
    end
  end

  describe "_fetch_enrichment" do
    whreq = Webhookdb::Replicator::WebhookRequest.new
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }
    let(:body) do
      JSON.parse(<<~J)
        {
          "id":1,
          "name":"The Broadcast",
          "created_at":"2021-09-22T20:40:49.000Z"
        }
      J
    end

    it "makes the request" do
      req = stub_request(:get, "https://api.convertkit.com/v3/broadcasts/1/stats?api_secret=").
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {broadcast: {id: 10_000_000, stats: {x: 1}}}.to_json,
        )
      svc._fetch_enrichment(body, nil, whreq)
      expect(req).to have_been_made
    end

    it "defaults stats" do
      req = stub_request(:get, "https://api.convertkit.com/v3/broadcasts/1/stats?api_secret=").
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {broadcast: {id: 5}}.to_json,
        )
      expect(svc._fetch_enrichment(body, nil, whreq)).to eq({})
      expect(req).to have_been_made
    end
  end
end
