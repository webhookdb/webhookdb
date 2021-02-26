# frozen_string_literal: true

RSpec.describe Webhookdb::Services, :db do
  it "raises for an invalid service" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
    expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
  end

  shared_examples "a service implementation" do |name|
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:body) { raise NotImplementedError }

    it "can create its table" do
      svc.create_table
      expect(sint.db.table_exists?(svc.table_sym)).to be_truthy
    end

    it "can insert into its table" do
      svc.create_table
      svc.upsert_webhook(body: body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(body)
    end

    it "handles webhooks" do
      status, headers, body = svc.webhook_response(Rack::Request.new({}))
      expect(status).to be_a(Integer)
      expect(headers).to be_a(Hash)
      expect(headers).to include("Content-Type")
      expect(body).to be_a(String)
    end
  end

  shared_examples "a service implementation that prevents overwriting new data with old" do |name|
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:old_body) { raise NotImplementedError }
    let(:new_body) { raise NotImplementedError }

    it "will override older rows with newer ones" do
      svc.create_table
      svc.upsert_webhook(body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(old_body)

      svc.upsert_webhook(body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
    end

    it "will not override newer rows with older ones" do
      svc.create_table

      svc.upsert_webhook(body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)

      svc.upsert_webhook(body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
    end
  end

  shared_examples "a service implementation that can backfill" do |name|
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: name,
        backfill_key: "bfkey",
        backfill_secret: "bfsek",
      )
    end
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:page1_items) { raise NotImplementedError }
    let(:page2_items) { raise NotImplementedError }

    it "upsert records for pages of results" do
      svc.create_table
      svc.backfill
      expect(svc.dataset.all).to have_length(page1_items.length + page2_items.length)
    end

    it "retries the page fetch" do
      svc.create_table
      expect(svc).to receive(:wait_for_retry_attempt).twice # Mock out the sleep
      expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
      expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
      expect(svc).to receive(:_fetch_backfill_page).and_call_original
      expect(svc).to receive(:_fetch_backfill_page).and_call_original
      expect(svc).to receive(:_fetch_backfill_page).and_call_original

      svc.backfill
      expect(svc.dataset.all).to have_length(page1_items.length + page2_items.length)
    end

    it "errors if backfill credentials are not present" do
      svc.service_integration.backfill_key = ""
      svc.service_integration.backfill_secret = ""
      expect { svc.backfill }.to raise_error(Webhookdb::Services::CredentialsMissing)
    end
  end

  describe "fake v1" do
    it_behaves_like "a service implementation", "fake_v1" do
      let(:body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "fake_v1" do
      let(:old_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
      let(:new_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2016 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation that can backfill", "fake_v1" do
      let(:page1_items) do
        [
          {"my_id" => "1", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
          {"my_id" => "2", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        ]
      end
      let(:page2_items) do
        [
          {"my_id" => "3", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
          {"my_id" => "4", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        ]
      end
      before(:each) do
        Webhookdb::Services::Fake.reset
        Webhookdb::Services::Fake.backfill_responses = {
          nil => [page1_items, "token1"],
          "token1" => [page2_items, "token2"],
          "token2" => [[], nil],
        }
      end
    end
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
      # rubocop:disable Layout/LineLength
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
    # rubocop:enable Layout/LineLength

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
  end
end
