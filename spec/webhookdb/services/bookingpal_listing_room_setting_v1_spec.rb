# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::BookingpalListingRoomSettingV1, :db do
  it_behaves_like "a service implementation", "bookingpal_listing_room_setting_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "listing_id": 174,
          "rooms": [
            {
              "room_type": "bedroom",
              "beds": [
                {
                  "bed_type": "TWIN_BED",
                  "bed_count": 2
                }
              ],
              "bath_count": 1
            },
            {
              "room_type": "living_room"
            }
          ]
        }
      J
    end
    let(:request_path) { "/v2/listing_rooms" }
    let(:request_method) { "POST" }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "bookingpal_listing_room_setting_v1",
                  "bookingpal_listing_v1" do
    let(:no_dependencies_message) { "This integration requires BookingPal Listings to sync" }
  end

  it_behaves_like "a service implementation that processes webhooks synchronously",
                  "bookingpal_listing_room_setting_v1" do
    let(:request_body) { {"listing_id" => 174} }
    let(:request_path) { "/v2/listing_rooms" }
    let(:request_method) { "POST" }
    let(:expected_synchronous_response) { {"listing_id" => 174}.to_json }
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_room_setting_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      status, _headers, body = svc.webhook_response(fake_request).to_rack
      expect(status).to eq(401)
      expect(body).to include("missing auth header")
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "api_key")
      req = fake_request
      req.add_header("API_KEY", "wrong_key")
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("invalid auth header")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "api_key")
      req = fake_request
      req.add_header("API_KEY", "api_key")
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      let(:listing_sint) do
        Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1")
      end
      let(:sint) do
        Webhookdb::Fixtures.service_integration.
          depending_on(listing_sint).
          create(service_name: "bookingpal_listing_room_setting_v1")
      end

      it "returns org database info" do
        sint.webhook_secret = "secret"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Once data is available, you can query BookingPal Listing Room Settings"),
        )
      end
    end
  end
end
