# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::BookingpalListingPhotoV1, :db do
  it_behaves_like "a service implementation", "bookingpal_listing_photo_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "listing_id": 174,
          "content_type": "image/jpeg",
          "filename": "filename8",
          "caption": "Je suis un caption",
          "sort_order": 2,
          "tags": [
            null
          ],
          "locale": "FR"
        }
      J
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "bookingpal_listing_photo_v1",
                  "bookingpal_listing_v1" do
    let(:no_dependencies_message) { "This integration requires BookingPal Listings to sync" }
  end

  it_behaves_like "a service implementation that processes webhooks synchronously", "bookingpal_listing_photo_v1" do
    let(:request_body) { {"listing_id" => 111} }
    let(:request_path) { "/v2/listing_photos" }
    let(:request_method) { "POST" }
    let(:expected_synchronous_response) { '{"photo_id":1,"listing_id":111}' }
  end

  describe "synchronous_processing_response" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_photo_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "is set to process webhooks synchronously" do
      expect(svc).to be_process_webhooks_synchronously
    end

    it "returns expected response on POST request" do
      req = Webhookdb::Services::WebhookRequest.new(
        body: {
          "listing_id" => 174,
          "content_type" => "image/jpeg",
          "filename" => "filename8",
        },
        path: "/v2/listing_photos",
        method: "POST",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to include(
        "listing_id" => 174,
        "content_type" => "image/jpeg",
        "filename" => "filename8",
        "photo_id" => 1,
      )
    end

    it "returns expected response on DELETE request of an existing row" do
      insert_result = svc.upsert_webhook(Webhookdb::Services::WebhookRequest.new(
                                           body: {"listing_id" => 174, "content_type" => "image/jpeg"},
                                           path: "/v2/listing_photos",
                                           method: "POST",
                                         ))
      photo_id = insert_result&.fetch(:photo_id)
      expect(photo_id).to be_an(Integer)
      delete_req = Webhookdb::Services::WebhookRequest.new(
        body: {},
        path: "/v2/listing_photos/#{photo_id}",
        method: "DELETE",
      )
      inserting = svc.upsert_webhook(delete_req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: delete_req)
      expect(JSON.parse(synch_resp)).to eq({"listing_id" => 174, "photo_id" => photo_id})
    end

    it "returns expected response on DELETE request of a missing row" do
      req = Webhookdb::Services::WebhookRequest.new(
        body: {},
        path: "/v2/listing_photos/444",
        method: "DELETE",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq({"listing_id" => nil, "photo_id" => 444})
    end
  end

  describe "webhook validation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_photo_v1")
    end
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
      let(:listing_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "bookingpal_listing_v1") }
      let(:sint) do
        Webhookdb::Fixtures.service_integration.
          depending_on(listing_sint).
          create(service_name: "bookingpal_listing_photo_v1")
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
          output: match("Once data is available, you can query BookingPal Listing Photos"),
        )
      end
    end
  end
end
