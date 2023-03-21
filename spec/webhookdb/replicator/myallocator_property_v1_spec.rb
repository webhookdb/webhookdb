# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorPropertyV1, :db do
  let(:root_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1") }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(service_name: "myallocator_property_v1")
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:create_property_body) do
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

  it_behaves_like "a replicator", "myallocator_property_v1" do
    let(:body) { create_property_body }
    let(:supports_row_diff) { false }
    let(:fake_request_env) { {"api.request.body" => {}} }
  end
  it_behaves_like "a replicator dependent on another", "myallocator_property_v1",
                  "myallocator_root_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Root to sync" }
  end

  it_behaves_like "a replicator that processes webhooks synchronously", "myallocator_property_v1" do
    let(:request_body) { create_property_body }
    let(:expected_synchronous_response) { {success: true, ota_property_id: upserted.fetch(:ota_property_id)}.to_json }
  end

  describe "webhook validation" do
    it "returns a 200 with designated MyAllocator error body if no shared secret" do
      req = fake_request(env: {"api.request.body" => {}})
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid credentials"}.to_json)
    end

    it "returns a 200 with designated MyAllocator error body for invalid shared secret" do
      sint.update(webhook_secret: "shared_secret")
      req = fake_request(env: {"api.request.body" => {"shared_secret" => "bad_secret"}})
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid credentials"}.to_json)
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
