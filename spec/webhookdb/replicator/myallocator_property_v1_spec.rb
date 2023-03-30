# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorPropertyV1, :db do
  let(:root_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1") }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(service_name: "myallocator_property_v1")
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:create_property_request_body) do
    {
      "ota_property_id" => "prop_id",
      "ota_property_password" => "prop_password",
      "ota_property_sub_id" => "",
      "mya_property_id" => 12_345,
      "ota_cid" => "ota",
      "verb" => "CreateProperty",
      "shared_secret" => "s3cr3ts4uc3",
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "Property" => {
        "name" => "Sample Hostel",
        "country" => "US",
        "currency" => "EUR",
        "email_default" => "someone@example.com",
        "email_channel_booking" => "bookings@example.com",
        "default_min_los" => 3,
        "default_max_los" => 0,
        "breakfast" => "",
        "weekend" => [],
        "firstname" => "John",
        "lastname" => "Smith",
        "timezone" => "Asia/Thimphu",
        "address" => {},
        "business_contact" => {},
        "images" => [],
        "rooms" => [],
      },
    }
  end
  let(:get_sub_properties_request_body) do
    {
      "verb" => "GetSubProperties",
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "very-secret-password",
      "ota_property_sub_id" => "",
      "mya_property_id" => 25_678,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
    }
  end

  it_behaves_like "a replicator", "myallocator_property_v1" do
    let(:body) { create_property_request_body }
    let(:supports_row_diff) { false }
    let(:fake_request_env) { {"api.request.body" => {}} }
  end
  it_behaves_like "a replicator dependent on another", "myallocator_property_v1",
                  "myallocator_root_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Root to sync" }
  end

  describe "synchronous_processing_response_body" do
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "returns success response with property cred info for 'CreateProperty' request" do
      request = Webhookdb::Replicator::WebhookRequest.new(
        body: create_property_request_body,
        method: "POST",
        path: "/CreateProperty",
      )
      upserted = svc.upsert_webhook(request)
      synch_resp = svc.synchronous_processing_response_body(upserted:, request:)
      expect(synch_resp).to eq(
        {
          "success" => true,
          "ota_property_id" => "prop_id",
          "ota_property_password" => "prop_password",
        }.to_json,
      )
    end

    it "returns expected subproperties for 'GetSubProperties' request" do
      svc.admin_dataset do |ds|
        ds.multi_insert(
          [
            {
              data: {}.to_json,
              mya_property_id: 1,
              ota_property_id: "ota_prop123",
              ota_property_password: "pass1",
              ota_property_sub_id: "sub1",
              name: "cool property",
            },
            {
              data: {}.to_json,
              mya_property_id: 2,
              ota_property_id: "ota_prop123",
              ota_property_password: "pass1",
              ota_property_sub_id: "sub2",
              name: "sweet digs",
            },
          ],
        )
      end

      request = Webhookdb::Replicator::WebhookRequest.new(
        body: get_sub_properties_request_body,
        method: "POST",
        path: "/GetSubProperties",
      )
      upserted = svc.upsert_webhook(request)
      synch_resp = svc.synchronous_processing_response_body(upserted:, request:)
      parsed_resp = JSON.parse(synch_resp)
      expect(parsed_resp.fetch("success")).to be true
      expect(parsed_resp.fetch("SubProperties")).to match_array(
        [
          {"title" => "cool property", "ota_property_sub_id" => "sub1"},
          {"title" => "sweet digs", "ota_property_sub_id" => "sub2"},
        ],
      )
    end
  end

  describe "upsert_webhook" do
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "noops for 'GetSubProperties'" do
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: get_sub_properties_request_body,
                                                        path: "/GetSubProperties",)
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end
  end

  describe "webhook validation" do
    it "returns a 200 with designated MyAllocator error body if no shared secret" do
      req = fake_request(env: {"api.request.body" => {}})
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid shared secret"}.to_json)
    end

    it "returns a 200 with designated MyAllocator error body for invalid shared secret" do
      sint.update(webhook_secret: "shared_secret")
      req = fake_request(env: {"api.request.body" => {"shared_secret" => "bad_secret"}})
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid shared secret"}.to_json)
    end

    it "returns a 200 with a valid shared secret" do
      sint.update(webhook_secret: "shared_secret")
      req = fake_request(env: {"api.request.body" => {"shared_secret" => "shared_secret"}})
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({o: "k"}.to_json)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "returns org database info" do
        sint.webhook_secret = "secret"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Once data is available, you can query MyAllocator Properties"),
        )
      end
    end
  end
end
