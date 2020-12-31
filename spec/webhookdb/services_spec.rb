# frozen_string_literal: true

RSpec.describe Webhookdb::Services, :db do
  it "raises for an invalid service" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
    expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
  end

  shared_examples "a service implementation" do |name|
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:headers) { {} }
    let(:body) { raise NotImplementedError }

    it "can create its table" do
      svc.create_table
      expect(sint.db.table_exists?(svc.table_sym)).to be_truthy
    end

    it "can insert into its table" do
      svc.create_table
      svc.upsert_webhook(headers: headers, body: body)
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
    let(:old_headers) { {} }
    let(:old_body) { raise NotImplementedError }
    let(:new_headers) { {} }
    let(:new_body) { raise NotImplementedError }

    it "will override older rows with newer ones" do
      svc.create_table
      svc.upsert_webhook(headers: old_headers, body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(old_body)

      svc.upsert_webhook(headers: new_headers, body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
    end

    it "will not override newer rows with older ones" do
      svc.create_table

      svc.upsert_webhook(headers: new_headers, body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)

      svc.upsert_webhook(headers: old_headers, body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
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
  end
end
