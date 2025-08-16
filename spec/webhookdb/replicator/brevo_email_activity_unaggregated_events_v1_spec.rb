# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1, :db do
  it_behaves_like "a replicator", "brevo_email_activity_unaggregated_events_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "email": "example@example.com",
          "date": "2024-01-23T09:34:13.916+08:00",
          "subject": "Brevo Test Transactional Mail",
          "messageId": "<202401230136.35720869946@smtp-relay.mailin.fr>",
          "event": "requests",
          "tag": "",
          "ip": "77.32.148.20",
          "from": "example@example.com"
        }
      J
    end
    let(:expected_data) { body }
  end

  it_behaves_like "a replicator that prevents overwriting new data with old",
                  "brevo_email_activity_unaggregated_events_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "email": "example@example.com",
          "date": "2024-01-23T09:34:13.916+08:00",
          "subject": "Brevo Test Transactional Mail",
          "messageId": "<202401230136.35720869946@smtp-relay.mailin.fr>",
          "event": "requests",
          "tag": "",
          "ip": "77.32.148.20",
          "from": "example@example.com"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "email": "example@example.com",
          "date": "2024-02-02T00:00:00.00+08:00",
          "subject": "Brevo Test Transactional Mail",
          "messageId": "<202401230136.35720869946@smtp-relay.mailin.fr>",
          "event": "requests",
          "tag": "",
          "ip": "77.32.148.20",
          "from": "example@example.com"
        }
      J
    end
    let(:expected_old_data) { old_body }
    let(:expected_new_data) { new_body }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:today) { Time.parse("2024-01-23T18:00:00Z") }
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "brevo_email_activity_unaggregated_events_v1",
        backfill_key: "bfkey",
        api_url: "https://api.brevo.com/v3",
        )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "brevo_email_activity_unaggregated_events_v1",
        backfill_key: "bfkey_wrong",
        api_url: "https://api.brevo.com/v3",
        )
    end

    let(:success_body) do
      <<~R
        {
          "events": []
        }
      R
    end

    def stub_service_request
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
          with(headers: {"api-key" => "bfkey"}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
          with(headers: {"api-key" => "bfkey_wrong"}).
          to_return(status: 401, body: "", headers: {})
    end

    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end
  end

  it_behaves_like "a replicator that can backfill", "brevo_email_activity_unaggregated_events_v1" do
    let(:today) { Time.parse("2024-01-23T18:00:00Z") }
    let(:api_url) { "https://api.brevo.com/v3" }
    let(:page1_response) do
      <<~R
        {
          "events": [
              {
                  "email": "example@example.com",
                  "date": "2024-01-23T09:34:13.916+08:00",
                  "subject": "Brevo Test Transactional Mail",
                  "messageId": "<202401230134.33146748018@smtp-relay.mailin.fr>",
                  "event": "requests",
                  "tag": "",
                  "ip": "77.32.148.20",
                  "from": "example@example.com"
              },
              {
                  "email": "example@example.com",
                  "date": "2024-01-23T09:34:14.000+08:00",
                  "subject": "Brevo Test Transactional Mail",
                  "messageId": "<202401230134.33146748018@smtp-relay.mailin.fr>",
                  "event": "delivered",
                  "tag": "",
                  "ip": "77.32.148.20",
                  "from": "example@example.com"
              },
              {
                  "email": "example@example.com",
                  "date": "2024-01-23T09:34:28.201+08:00",
                  "subject": "Brevo Test Transactional Mail",
                  "messageId": "<202401230134.33146748018@smtp-relay.mailin.fr>",
                  "event": "opened",
                  "tag": "",
                  "ip": "74.125.209.36",
                  "from": "example@example.com"
              },
              {
                  "email": "example@example.com",
                  "date": "2024-01-23T19:10:10.063+08:00",
                  "subject": "Brevo Test Transactional Mail",
                  "messageId": "<202401230134.33146748018@smtp-relay.mailin.fr>",
                  "event": "opened",
                  "tag": "",
                  "ip": "74.125.209.35",
                  "from": "example@example.com"
              }
          ]
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "events": []
        }
      R
    end
    let(:expected_items_count) { 4 }

    def stub_service_requests
      return [
        stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
          with(headers: {"api-key" => "bfkey"}).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=100&startDate=2023-10-25&endDate=2024-01-23").
          with(headers: {"api-key" => "bfkey"}).
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
          to_return(status: 400, body: "geh")
    end

    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "brevo_email_activity_unaggregated_events_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns 202 if the remote addr is valid" do
      req = fake_request
      req.add_header("REMOTE_ADDR", "185.107.232.2")
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end

    it "returns 401 if the remote addr is invalid" do
      req = fake_request
      req.add_header("REMOTE_ADDR", "1.1.1.1")
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "brevo_email_activity_unaggregated_events_v1", api_url: "") }
    let(:svc) { Webhookdb::Replicator.create(sint) }
    let(:today) { Time.parse("2024-01-23T18:00:00Z") }

    describe "process_state_change" do
      it "uses a default api url if value is blank" do
        sint.replicator.process_state_change("api_url", "")
        expect(sint.api_url).to eq("https://api.brevo.com/v3")
      end
    end

    describe "calculate_webhook_state_machine" do
      it "prompts with instructions" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Press Enter after Save Webhook succeeds:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/noop_create"),
          complete: false,
          output: start_with("You are about to set up webhooks for Transactional Email Activity (Unaggregated Events)."),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      let(:today) { Time.parse("2024-01-23T18:00:00Z") }
      let(:success_body) do
        <<~R
          {
            '{}'
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0&startDate=2023-10-25&endDate=2024-01-23").
            with(headers: {"api-key" => "bfkey"}).
            to_return(status: 200, body: success_body, headers: {})
      end

      it "asks for backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API Key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to backfill Transactional Email Activity (Unaggregated Events), we need an API key.
If you don't have one, you can generate it by going to your Brevo \"My Account Dashboard\", click your profile name's dropdown,
then go to SMTP & API -> Generate a new API key."),
        )
      end

      it "asks for api url" do
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API url here:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/api_url"),
          complete: false,
          output: match("Now we want to make sure we're sending API requests to the right place"),
        )
      end

      it "confirms reciept of api url, returns org database info" do
        sint.backfill_key = "bfkey"
        sint.api_url = "https://api.brevo.com/v3"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: start_with("Great! We are going to start backfilling your Transactional Email Activity (Unaggregated Events)."),
        )
      end
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
    end
  end
end
