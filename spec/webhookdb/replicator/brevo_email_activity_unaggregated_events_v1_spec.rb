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
          "date": "2024-01-23T09:34:28.201+08:00",
          "subject": "Brevo Test Transactional Mail",
          "messageId": "<202401230136.35720869946@smtp-relay.mailin.fr>",
          "event": "opened",
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
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?days=90").
        with(headers: {"api-key" => "bfkey"}).
        to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?days=90").
        with(headers: {"api-key" => "bfkey_wrong"}).
        to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "brevo_email_activity_unaggregated_events_v1" do
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
        {}
      R
    end
    let(:expected_items_count) { 4 }
    def stub_service_requests
      return [
        stub_request(:get, "https://api.brevo.com/v3").
          with(headers: {"Authorization" => "Bearer bfkey"}).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?limit=10&offset=0&sort=desc&event=requests&startDate=2024-01-22&endDate=2024-01-22").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?days=90").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events?days=90").
        to_return(status: 400, body: "geh")
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

  # May be deleted
  describe "helper tests" do
    let(:allowed_ip_blocks) { %w[185.107.232.1/24 1.179.112.1/20] }

    it "ip is valid" do
      ip = "185.107.232.2"
      allowed = allowed_ip_blocks.any?{|block| IPAddr.new(block, Socket::AF_INET) === IPAddr.new(ip, Socket::AF_INET) }
      # $stderr.puts ">>>>> allowed = #{allowed}"
      expect(allowed).to be true
    end

    it "ip is invalid" do
      ip = "1.1.1.1"
      allowed = allowed_ip_blocks.any?{ |block| IPAddr.new(block, Socket::AF_INET) === IPAddr.new(ip, Socket::AF_INET) }
      # $stderr.puts ">>>>> allowed = #{allowed}"
      expect(allowed).to be false
    end

    it "replaces a key in a hash" do
      body = {"message-id" => "first-id"}
      body[:messageId] = body.delete "message-id"
      # $stderr.puts ">>>>> body[:messageId] = #{body[:messageId]}"
      expect(body[:messageId]).to eq "first-id"
    end
  end
end
