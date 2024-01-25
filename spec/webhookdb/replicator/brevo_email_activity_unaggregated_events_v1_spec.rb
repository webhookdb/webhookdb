# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1, :db do
  it_behaves_like "a replicator", "brevo_email_activity_unaggregated_events_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "event": "created",
          "email": "example@example.com",
          "id": 26224,
          "date": "YYYY-MM-DD HH:mm:ss",
          "ts": 1598634509,
          "message-id": "<xxxxxxxxxxxx.xxxxxxxxx@domain.com>",
          "ts_event": 1598034509,
          "subject": "Subject Line",
          "sending_ip": "185.41.28.109",
          "ts_epoch": 1598634509223,
          "tags": [
            "myFirstTransactional"
          ]
        }
      J
    end
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
          "event": "created",
          "email": "example@example.com",
          "id": 26224,
          "date": "YYYY-MM-DD HH:mm:ss",
          "ts": 1598634509,
          "message-id": "<xxxxxxxxxxxx.xxxxxxxxx@domain.com>",
          "ts_event": 1598034509,
          "subject": "Subject Line",
          "sending_ip": "185.41.28.109",
          "ts_epoch": 1598634509223,
          "tags": [
            "myFirstTransactional"
          ]
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events").
        with(headers: {"api-key" => "bfkey"}).
        to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.brevo.com/v3/smtp/statistics/events").
        with(headers: {"api-key" => "bfkey_wrong"}).
        to_return(status: 401, body: "", headers: {})
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

    it "returns 401 if neither ip is valid" do
      req = fake_request
      req.add_header("REMOTE_ADDR", "1.1.1.1")
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
    end
  end

  describe "helper tests" do
    let(:allowed_ip_blocks) { %w[185.107.232.1/24 1.179.112.1/20] }

    it "ip is valid" do
      ip = "185.107.232.2"
      allowed = allowed_ip_blocks.any?{|block| IPAddr.new(block) === IPAddr.new(ip) }
      # $stderr.puts ">>>>> allowed = #{allowed}"
      expect(allowed).to be true
    end

    it "ip is invalid" do
      ip = "1.1.1.1"
      allowed = allowed_ip_blocks.any?{ |block| IPAddr.new(block) === IPAddr.new(ip) }
      # $stderr.puts ">>>>> allowed = #{allowed}"
      expect(allowed).to be false
    end

    it "correctly replaces a key in a hash" do
      body = {"message-id" => "first-id"}
      body[:messageId] = body.delete "message-id"
      # $stderr.puts ">>>>> body[:messageId] = #{body[:messageId]}"
      expect(body[:messageId]).to eq "first-id"
    end
  end
end
