# frozen_string_literal: true

require "webhookdb/increase"

RSpec.describe "Webhookdb::Increase" do
  let(:described_class) { Webhookdb::Increase }

  describe "webhook_response" do
    it "returns a 401 as per spec if there is no Authorization header" do
      req = fake_request
      data = req.body
      status, headers, _body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(401)
    end

    it "returns a 401 for an invalid Authorization header" do
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "webhook_secret", '{"data": "foobar"}')
      req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
      status, _headers, body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 200 with a valid Authorization header" do
      req = fake_request(input: '{"data": "asdfghujkl"}')
      data = req.body
      computed_auth = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "webhook_secret", data)
      req.add_header("HTTP_X_BANK_WEBHOOK_SIGNATURE", "sha256=" + computed_auth)
      status, _headers, _body = Webhookdb::Increase.webhook_response(req, "webhook_secret")
      expect(status).to eq(200)
    end
  end

  describe "webhook_contains_object" do
    let(:webhook_body) do
      JSON.parse(<<~J)
        {"event_id": "transaction_event_123",
                  "event": "created",
                  "created_at": "2020-01-31T23:59:59Z",
                  "data": {
                    "id": "transaction_uyrp7fld2ium70oa7oi",
                    "account_id": "account_in71c4amph0vgo2qllky",
                    "amount": 100,
                    "date": "2020-01-10",
                    "description": "Rent payment",
                    "route_id": "ach_route_yy0yirrxa4pblzl0k4op",
                    "path": "/transactions/transaction_uyrp7fld2ium70oa7oi",
                    "source": {}
                  }
                  }
      J
    end
    it "returns true when object name is in the id of the webhook object" do
      expect(Webhookdb::Increase.contains_desired_object(webhook_body, "transaction")).to eq(true)
    end
    it "returns false when object name is not in the id of the webhook object" do
      expect(Webhookdb::Increase.contains_desired_object(webhook_body, "transfer")).to eq(false)
    end
  end

  describe "find_object_data" do
    let(:webhook_body) do
      JSON.parse(<<~J)
                            {"event_id": "transaction_event_123",
        "event": "created",
        "created_at": "2020-01-31T23:59:59Z",
        "data": {
          "id": "transaction_uyrp7fld2ium70oa7oi",
          "account_id": "account_in71c4amph0vgo2qllky",
          "amount": 100,
          "date": "2020-01-10",
          "description": "Rent payment",
          "route_id": "ach_route_yy0yirrxa4pblzl0k4op",
          "path": "/transactions/transaction_uyrp7fld2ium70oa7oi",
          "source": {}
        }
        }
      J
    end

    let(:object_json) do
      JSON.parse(<<~J)
                            {
          "id": "transaction_uyrp7fld2ium70oa7oi",
          "account_id": "account_in71c4amph0vgo2qllky",
          "amount": 100,
          "date": "2020-01-10",
          "description": "Rent payment",
          "route_id": "ach_route_yy0yirrxa4pblzl0k4op",
          "path": "/transactions/transaction_uyrp7fld2ium70oa7oi",
          "source": {}
        }

      J
    end

    it "returns object data from webhook body" do
      expect(Webhookdb::Increase.find_desired_object_data(webhook_body)).to eq(object_json)
    end
    it "returns object json intact" do
      expect(Webhookdb::Increase.find_desired_object_data(object_json)).to eq(object_json)
    end
  end
end
