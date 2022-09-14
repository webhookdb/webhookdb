# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::BookingpalListingV1, :db do
  it_behaves_like "a service implementation", "bookingpal_listing_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "name": "Casa Armadillo",
          "apt": "Unit 8",
          "street": "78 Polarino Uno",
          "city": "Portland",
          "country_code": "US",
          "lat": 10.624561,
          "lng": -85.68527,
          "listing_currency": "USD",
          "detailed_description": "Located on the main floor. Sitting area, en-suite bathroom. The interior living areas open fully to two swimming pools, one cascading into the other, and to the ample decking surrounding both. Covered outdoor lounging and dining areas allow guests to take full advantage of these views, and there are numerous opportunities for sunning poolside, too.\\nThe property has seven bedrooms, including five roomy suites that open to a terrace or the deck, and two single rooms. The home is fully air conditioned, has WiFi, flat-screen TVs and a games room with a ping-pong table. Guests enjoy access to all the facilities at Peninsula Papagayo, including the private Prieta Beach Club, golf, tennis, dining and fitness facilities.",
          "guests_included": 12,
          "pm_name": "Jose Hernandez",
          "pm_id": 248,
          "pricing_model": "pricing_model4",
          "listing_type_category": "PCT6",
          "bedrooms": 2,
          "bathrooms": 2.5,
          "beds": 4,
          "amenity_categories": [
            "RM156"
          ],
          "check_in_option": "Afternoon ",
          "permit_or_tax_id": "permit id ",
          "state": "OR",
          "zipcode": "97227",
          "person_capacity": 8,
          "short_description": "short desc",
          "neighborhood_overview": "it'\''s on a hill ",
          "transit": "bus is good",
          "house_rules": "no rules",
          "locale": "en ",
          "booking_settings": "inquiry_only",
          "flags": "Popular/Trending, Expert approved, Inquiry to book",
          "primary_contact": "18006666666",
          "contacts": [
            {}
          ],
          "space": {
            "size": 1000,
            "unit": "ft2"
          },
          "listing_type_group": "listing type group ",
          "min_advance_booking_offset": " P5H ",
          "max_advance_booking_offset": " P14D"
        }
      J
    end
    let(:request_path) { "/v2/listings/182" }
    let(:request_method) { "POST" }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation that processes webhooks synchronously", "bookingpal_listing_v1" do
    let(:request_body) { {"name" => "abc"} }
    let(:request_path) { "/v2/listings/123" }
    let(:request_method) { "PUT" }
    let(:expected_synchronous_response) { '{"schema":{"listing_id":123,"name":"abc"}}' }
  end

  describe "incremental updates" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "does not stomp existing values in the row" do
      svc.upsert_webhook(
        Webhookdb::Services::WebhookRequest.new(
          body: {"name" => "Casa Armadillo", "apt" => "S123"},
          method: "POST",
          path: "/v2/listings/444",
        ),
      )
      expect(svc.admin_dataset(&:all)).to contain_exactly(include(apt: "S123", name: "Casa Armadillo"))
      svc.upsert_webhook(
        Webhookdb::Services::WebhookRequest.new(
          body: {"apt" => "X555"},
          method: "POST",
          path: "/v2/listings/444",
        ),
      )
      expect(svc.admin_dataset(&:all)).to contain_exactly(include(apt: "X555", name: "Casa Armadillo"))
    end
  end

  describe "synchronous_processing_response_body" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "returns expected response on POST request" do
      req = Webhookdb::Services::WebhookRequest.new(
        body: {"name" => "Casa Armadillo"},
        method: "POST",
        path: "/v2/listings",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq(
        {
          "schema" => {
            "listing_id" => 1,
            "name" => "Casa Armadillo",
          },
        },
      )
    end

    it "returns expected response on PUT request" do
      req = Webhookdb::Services::WebhookRequest.new(
        body: {"name" => "Casa Armadillo"},
        method: "PUT",
        path: "/v2/listings/182",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq(
        {
          "schema" => {
            "listing_id" => 182,
            "name" => "Casa Armadillo",
          },
        },
      )
    end

    it "returns expected response on DELETE request" do
      req = Webhookdb::Services::WebhookRequest.new(
        method: "DELETE",
        path: "/v2/listings/123",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq({"listing_id" => 123})
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      status, headers, body = svc.webhook_response(fake_request).to_rack
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
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1") }

      it "asks for webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your webhook secret here:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("In order to authenticate"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "secret"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("WebhookDB will pass this authentication"),
        )
      end
    end
  end
end
