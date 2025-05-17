# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::SignalwireMessageV1, :db do
  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "account_sid": "AC123",
          "api_version": "2010-04-01",
          "body": "body",
          "date_created": "Thu, 30 Jul 2015 20:12:31 +0000",
          "date_sent": "Thu, 30 Jul 2015 20:12:33 +0000",
          "date_updated": "Thu, 30 Jul 2015 20:12:33 +0000",
          "direction": "outbound-api",
          "error_code": null,
          "error_message": null,
          "from": "+15017122661",
          "messaging_service_sid": "MGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "num_media": "0",
          "num_segments": "1",
          "price": null,
          "price_unit": null,
          "sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "status": "sent",
          "subresource_uris": {
            "media": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
          },
          "to": "+15558675310",
          "uri": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
        }
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "account_sid": "AC123",
          "api_version": "2010-04-01",
          "body": "body",
          "date_created": "Thu, 30 Jul 2015 20:12:31 +0000",
          "date_sent": "Thu, 30 Jul 2015 20:12:33 +0000",
          "date_updated": "Thu, 30 Jul 2015 20:12:33 +0000",
          "direction": "outbound-api",
          "error_code": null,
          "error_message": null,
          "from": "+15017122661",
          "messaging_service_sid": "MGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "num_media": "0",
          "num_segments": "1",
          "price": null,
          "price_unit": null,
          "sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "status": "sent",
          "subresource_uris": {
            "media": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
          },
          "to": "+15558675310",
          "uri": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "account_sid": "AC123",
          "api_version": "2010-04-01",
          "body": "body",
          "date_created": "Thu, 30 Jul 2015 20:12:31 +0000",
          "date_sent": "Thu, 30 Jul 2015 20:12:33 +0000",
          "date_updated": "Thu, 30 Jul 2016 20:12:33 +0000",
          "direction": "outbound-api",
          "error_code": null,
          "error_message": null,
          "from": "+15017122661",
          "messaging_service_sid": "MGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "num_media": "0",
          "num_segments": "1",
          "price": null,
          "price_unit": null,
          "sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "status": "sent",
          "subresource_uris": {
            "media": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
          },
          "to": "+15558675310",
          "uri": "/2010-04-01/Accounts/AC123/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "signalwire_message_v1",
        backfill_key: "bfkey",
        backfill_secret: "bfsek",
        api_url: "whdbtestfake",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "signalwire_message_v1",
        backfill_key: "bfkey_wrong",
        backfill_secret: "bfsek",
        api_url: "whdbtestfake",
      )
    end

    let(:success_body) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "messages": [
            {}
          ],
          "start": 0,
          "uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0"
        }
      R
    end

    let(:failed_step_matchers) do
      {output: include("Something is wrong with your configuration"), prompt_is_secret: false}
    end

    def stub_service_request
      return stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
          with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey_wrong/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
        with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6YmZzZWs="}).
        to_return(status: 401, body: "", headers: {})
    end

    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end
  end

  it_behaves_like "a replicator that can backfill" do
    let(:api_url) { "whdbtestfake" }
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "messages": [
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "testing",
              "date_created": "Fri, 24 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 24 May 2019 17:44:50 +0000",
              "date_updated": "Fri, 24 May 2019 17:44:50 +0000",
              "direction": "outbound-api",
              "error_code": null,
              "error_message": null,
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "0",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "SMded05904ccb347238880ca9264e8fe1c",
              "status": "sent",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
            },
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "look mom I have media!",
              "date_created": "Fri, 24 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 24 May 2019 17:44:49 +0000",
              "date_updated": "Fri, 24 May 2019 17:44:49 +0000",
              "direction": "inbound",
              "error_code": 30004,
              "error_message": "Message blocked",
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "3",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "MMc26223853f8c46b4ab7dfaa6abba0a26",
              "status": "received",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26.json"
            }
          ],
          "start": 0,
          "uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "never see this",
          "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=SomeOtherToken",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "never see this",
          "messages": [
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "testing",
              "date_created": "Fri, 24 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 24 May 2019 17:44:50 +0000",
              "date_updated": "Fri, 24 May 2019 17:44:50 +0000",
              "direction": "outbound-api",
              "error_code": null,
              "error_message": null,
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "0",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "SMabcxyz",
              "status": "sent",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
            }
          ],
          "start": 0,
          "uri": "never see this"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "never see this",
          "next_page_uri": "",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "never see this",
          "messages": [],
          "start": 0,
          "uri": "never see this"
        }
      R
    end
    let(:expected_items_count) { 3 }
    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
            with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/AC123/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26&To=%2B123456789").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/AC123/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=SomeOtherToken&To=%2B123456789").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
          to_return(status: 402, body: "woah")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally" do
    let(:api_url) { "whdbtestfake" }
    let(:today) { Time.parse("2020-11-22T18:00:00Z") }
    let(:page1_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
          "messages": [
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "testing",
              "date_created": "Fri, 24 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 24 May 2019 17:44:50 +0000",
              "date_updated": "Fri, 24 May 2019 17:44:50 +0000",
              "direction": "outbound-api",
              "error_code": null,
              "error_message": null,
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "0",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "SMded05904ccb347238880ca9264e8fe1c",
              "status": "sent",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
            },
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "look mom I have media!",
              "date_created": "Fri, 01 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 01 May 2019 17:44:49 +0000",
              "date_updated": "Fri, 01 May 2019 17:44:49 +0000",
              "direction": "inbound",
              "error_code": 30004,
              "error_message": "Message blocked",
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "3",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "MMc26223853f8c46b4ab7dfaa6abba0a26",
              "status": "received",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26.json"
            }
          ],
          "start": 0,
          "uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0"
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "never see this",
          "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=SomeOtherToken",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "never see this",
          "messages": [
            {
              "account_sid": "AC123",
              "api_version": "2010-04-01",
              "body": "testing",
              "date_created": "Fri, 24 May 2019 17:44:46 +0000",
              "date_sent": "Fri, 24 May 2019 17:44:50 +0000",
              "date_updated": "Fri, 24 May 2019 17:44:50 +0000",
              "direction": "outbound-api",
              "error_code": null,
              "error_message": null,
              "from": "+12019235161",
              "messaging_service_sid": null,
              "num_media": "0",
              "num_segments": "1",
              "price": "-0.00750",
              "price_unit": "USD",
              "sid": "SMabcxyz",
              "status": "sent",
              "subresource_uris": {
                "media": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                "feedback": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
              },
              "to": "+18182008801",
              "uri": "/2010-04-01/Accounts/AC123/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
            }
          ],
          "start": 0,
          "uri": "never see this"
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "end": 1,
          "first_page_uri": "never see this",
          "next_page_uri": "",
          "page": 0,
          "page_size": 2,
          "previous_page_uri": "never see this",
          "messages": [],
          "start": 0,
          "uri": "never see this"
        }
      R
    end
    let(:last_backfilled) { "2019-05-15T18:00:00Z" }

    let(:expected_new_items_count) { 2 }
    let(:expected_old_items_count) { 1 }

    around(:each) do |example|
      Timecop.travel(today) do
        example.run
      end
    end

    def stub_service_requests(partial:)
      new_reqs = [
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
          with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
      return new_reqs if partial
      old_reqs = [
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/AC123/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26&To=%2B123456789").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://whdbtestfake.signalwire.com/2010-04-01/Accounts/AC123/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=SomeOtherToken&To=%2B123456789").
          to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
      return old_reqs + new_reqs
    end
  end

  it_behaves_like "a replicator that alerts on backfill auth errors" do
    let(:sint_params) { {api_url: "namespace"} }
    let(:template_name) { "errors/generic_backfill" }

    around(:each) do |example|
      Timecop.travel("2024-01-15T00:00:00Z") do
        example.run
      end
    end

    def stub_service_request
      return stub_request(:get, "https://namespace.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2024-01-17&PageSize=100")
    end

    def handled_responses
      return [
        [:and_return, {status: 401, body: "Unauthorized"}],
        [:and_raise, SocketError.new("Failed to open TCP connection to .signalwire.com:443")],
      ]
    end

    def unhandled_response
      return [:and_return, {status: 500, body: "Error"}]
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "signalwire_message_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      req = Rack::Request.new({})
      status, headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(headers).to include("WWW-Authenticate" => 'Basic realm="Webhookdb"')
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "secureuser:pass")
      req = Rack::Request.new({})
      req.add_header("Authorization", "Basic " + Base64.encode64("user:pass"))
      status, headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(headers).to_not include("WWW-Authenticate")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = Rack::Request.new({})
      req.add_header("Authorization", "Basic " + Base64.encode64("user:pass"))
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "signalwire_message_v1", backfill_secret: "", backfill_key: "", api_url: "",
      )
    end
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_backfill_state_machine" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }
      let(:success_body) do
        <<~R
          {
            "end": 1,
            "first_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
            "next_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26",
            "page": 0,
            "page_size": 2,
            "previous_page_uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
            "messages": [
              {}
            ],
            "start": 0,
            "uri": "/2010-04-01/Accounts/AC123/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0"
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://fakespace.signalwire.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-24&PageSize=100").
            with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
            to_return(status: 200, body: success_body, headers: {})
      end

      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end

      it "asks for api/space url" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("Paste or type your Space URL"),
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/api_url"),
          complete: false,
          output: include("You can see this on your SignalWire dashboard"),
        )
      end

      it "uses the first subdomain if .signalwire.com is included in the space url" do
        sint.replicator.process_state_change("api_url", "https://whdb.signalwire.com")
        expect(sint).to have_attributes(api_url: "whdb")
        sint.replicator.process_state_change("api_url", "whdb.signalwire.com/foo/bar")
        expect(sint).to have_attributes(api_url: "whdb")
      end

      it "asks for backfill/project id" do
        sint.api_url = "fakespace"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("type your Project ID"),
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: include("Go to https://fakespace.signalwire.com/credentials and copy"),
        )
      end

      it "asks for backfill secret" do
        sint.api_url = "fakespace"
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("your API Token here"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: include("Press 'Show' next to the newly-created API token"),
        )
      end

      it "returns org database info" do
        sint.api_url = "fakespace"
        sint.backfill_key = "bfkey"
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
          output: include("replicating your SignalWire Messages"),
        )
      end
    end
  end
end
