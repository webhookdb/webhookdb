# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  it "raises for an invalid service" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
    expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
  end

  describe "twilio sms v1" do
    it_behaves_like "a service implementation", "twilio_sms_v1" do
      let(:body) do
        JSON.parse(<<~J)
            {
            "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
              "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
            },
            "to": "+15558675310",
            "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
          }
        J
      end
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "twilio_sms_v1" do
      let(:old_body) do
        JSON.parse(<<~J)
            {
            "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
              "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
            },
            "to": "+15558675310",
            "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
          }
        J
      end
      let(:new_body) do
        JSON.parse(<<~J)
            {
            "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
              "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Media.json"
            },
            "to": "+15558675310",
            "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.json"
          }
        J
      end
    end

    it_behaves_like "a service implementation that can backfill", "twilio_sms_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [{}] }
      let(:page1_response) do
        <<~R
          {
            "end": 1,
            "first_page_uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
            "next_page_uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26",
            "page": 0,
            "page_size": 2,
            "previous_page_uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0",
            "messages": [
              {
                "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
                  "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                  "feedback": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
                },
                "to": "+18182008801",
                "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
              },
              {
                "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
                  "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Media.json",
                  "feedback": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26/Feedback.json"
                },
                "to": "+18182008801",
                "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/MMc26223853f8c46b4ab7dfaa6abba0a26.json"
              }
            ],
            "start": 0,
            "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=0"
          }
        R
      end
      let(:page2_response) do
        <<~R
          {
            "end": 1,
            "first_page_uri": "never see this",
            "next_page_uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?To=%2B123456789&From=%2B987654321&DateSent%3E=2008-01-02&PageSize=2&Page=1&PageToken=SomeOtherToken",
            "page": 0,
            "page_size": 2,
            "previous_page_uri": "never see this",
            "messages": [
              {
                "account_sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
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
                  "media": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c/Media.json",
                  "feedback": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c/Feedback.json"
                },
                "to": "+18182008801",
                "uri": "/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages/SMded05904ccb347238880ca9264e8fe1c.json"
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
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      before(:each) do
        stub_request(:get, "https://api.twilio.com/2010-04-01/Accounts/bfkey/Messages.json?DateSend%3C=2020-11-23&PageSize=100").
          with(
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Authorization" => "Basic YmZrZXk6YmZzZWs=",
              "User-Agent" => "Ruby",
            },
          ).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.twilio.com/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=PAMMc26223853f8c46b4ab7dfaa6abba0a26&To=%2B123456789").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.twilio.com/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json?DateSent%3E=2008-01-02&From=%2B987654321&Page=1&PageSize=2&PageToken=SomeOtherToken&To=%2B123456789").
          to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"})
      end
    end

    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "twilio_sms_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "returns a 401 as per spec if there is no Authorization header" do
        req = Rack::Request.new({})
        status, headers, _body = svc.webhook_response(req)
        expect(status).to eq(401)
        expect(headers).to include("WWW-Authenticate" => 'Basic realm="Webhookdb"')
      end

      it "returns a 401 for an invalid Authorization header" do
        sint.update(webhook_secret: "secureuser:pass")
        req = Rack::Request.new({})
        req.add_header("Authorization", "Basic " + Base64.encode64("user:pass"))
        status, headers, _body = svc.webhook_response(req)
        expect(status).to eq(401)
        expect(headers).to_not include("WWW-Authenticate")
      end

      it "returns a 200 with a valid Authorization header" do
        sint.update(webhook_secret: "user:pass")
        req = Rack::Request.new({})
        req.add_header("Authorization", "Basic " + Base64.encode64("user:pass"))
        status, _headers, _body = svc.webhook_response(req)
        expect(status).to eq(202)
      end
    end

    describe "state machine calculation" do
      let(:sint) do
        Webhookdb::Fixtures.service_integration.create(service_name: "twilio_sms_v1", backfill_secret: "",
                                                       backfill_key: "",)
      end
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      describe "calculate_create_state_machine" do
        it "returns org database info" do
          sint.webhook_secret = "whsec_abcasdf"
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! We've created your Twilio SMS Service Integration.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "asks for backfill key" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your Account SID here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("https://api.webhookdb.com/v1/service_integrations/#{sint.opaque_id}/transition/backfill_key")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match(
            "In order to backfill Twilio SMS, we need your Account SID and Auth Token.",
          )
        end

        it "asks for backfill secret" do
          sint.backfill_key = "key_ghjkl"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your Auth Token here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("https://api.webhookdb.com/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to be_nil
        end

        it "returns org database info" do
          sint.backfill_key = "key_ghjkl"
          sint.backfill_secret = "whsec_abcasdf"
          sint.api_url = "https://shopify_test.myshopify.com"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your Twilio SMS information.",
          )
        end
      end
    end
  end
end
