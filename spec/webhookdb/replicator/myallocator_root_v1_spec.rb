# frozen_string_literal: true

require "support/shared_examples_for_replicators"
require "rack"

RSpec.describe Webhookdb::Replicator::MyallocatorRootV1, :db do
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1", backfill_key: "api_key")
  end
  let(:svc) { sint.replicator }

  def request_to(uri)
    env = Rack::MockRequest.env_for(uri)
    return fake_request(env:)
  end

  it "can create its table in its org db" do
    sint.organization.prepare_database_connections
    svc.create_table
    svc.readonly_dataset do |ds|
      expect(ds.db).to be_table_exists(svc.qualified_table_sequel_identifier)
    end
    expect(sint.db).to_not be_table_exists(svc.qualified_table_sequel_identifier)
    sint.organization.remove_related_database
  end

  describe "backfill" do
    it "noops" do
      svc.backfill
    end
  end

  describe "upsert_webhook" do
    it "noops" do
      svc.upsert_webhook(fake_request)
    end
  end

  describe "synchronous_processing_response_body" do
    it "returns success body" do
      resp = svc.synchronous_processing_response_body
      expect(resp).to eq("{\"success\":true}")
    end
  end

  describe "state machine calculation" do
    # `calculate_backfill_state_machine` just calls `calculate_create_state_machine`,
    # so it doesn't need to be tested
    describe "calculate_create_state_machine" do
      before(:each) do
        sint.update(webhook_secret: "")
      end

      it "asks for webhook secret (api key)" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your webhook secret here:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match("In order to authenticate information recieved from BookingPal"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "password"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("WebhookDB will pass this authentication information on to dependents"),
        )
      end
    end
  end

  describe "dispatch_request_to" do
    let(:root_sint) { Webhookdb::Fixtures.service_integration(service_name: "myallocator_root_v1").create }
    let(:root_svc) { root_sint.replicator }
    let(:fac) { Webhookdb::Fixtures.service_integration.depending_on(root_sint) }

    def request_to(uri)
      env = Rack::MockRequest.env_for(uri)
      return fake_request(env:)
    end

    it "dispatches 'HealthCheck' requests to root sint" do
      health_check_req = request_to("http://example.com/HealthCheck")
      expect(root_svc.dispatch_request_to(health_check_req).service_integration).to eq(root_sint)
    end

    it "dispatches 'ARIUpdate' requests to ari sint" do \
      ari_sint = fac.create(service_name: "myallocator_ari_v1")
      ari_update_req = request_to("http://example.com/ARIUpdate")
      expect(root_svc.dispatch_request_to(ari_update_req).service_integration).to eq(ari_sint)
    end

    it "dispatches 'BookingCreate', 'GetBookingList', & 'GetBookingId' requests to booking sint" do
      booking_sint = fac.create(service_name: "myallocator_booking_v1")
      booking_create_req = request_to("http://example.com/BookingCreate")
      expect(root_svc.dispatch_request_to(booking_create_req).service_integration).to eq(booking_sint)
      booking_list_req = request_to("http://example.com/GetBookingList")
      expect(root_svc.dispatch_request_to(booking_list_req).service_integration).to eq(booking_sint)
      booking_detail_req = request_to("http://example.com/GetBookingId")
      expect(root_svc.dispatch_request_to(booking_detail_req).service_integration).to eq(booking_sint)
    end

    it "dispatches 'CreateProperty' requests to property sint" do
      property_sint = fac.create(service_name: "myallocator_property_v1")
      create_property_req = request_to("http://example.com/CreateProperty")
      expect(root_svc.dispatch_request_to(create_property_req).service_integration).to eq(property_sint)
    end

    it "dispatches 'SetupProperty' & 'GetRoomType' requests to room sint" do
      room_sint = fac.create(service_name: "myallocator_room_v1")
      setup_property_req = request_to("http://example.com/SetupProperty")
      expect(root_svc.dispatch_request_to(setup_property_req).service_integration).to eq(room_sint)
      get_room_types_req = request_to("http://example.com/GetRoomTypes")
      expect(root_svc.dispatch_request_to(get_room_types_req).service_integration).to eq(room_sint)
    end

    it "raises RuntimeError when url is not handled by case statement" do
      expect do
        root_svc.dispatch_request_to(request_to("http://example.com/Foo"))
      end.to raise_error(RuntimeError, %r{invalid path: '/Foo'})
    end
  end

  describe "get_dependent_sint" do
    let(:root_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1", backfill_key: "api_key")
    end

    it "returns expected dependent integration with given service name" do
      listing_sint = Webhookdb::Fixtures.service_integration.depending_on(root_sint).
        create(service_name: "myallocator_booking_v1")
      expect(root_sint.dependents.first).to eq(listing_sint)
      result = root_sint.replicator.get_dependent_integration("myallocator_booking_v1")
      expect(result).to eq(listing_sint)
    end

    it "errors if there is no dependent integration with given service name" do
      expect do
        root_sint.replicator.get_dependent_integration("myallocator_booking_v1")
      end.to raise_error(Webhookdb::InvalidPrecondition, /there is no myallocator_booking_v1 integration/)
    end

    it "errors if there are multiple dependent integrations with given service name" do
      Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(service_name: "myallocator_booking_v1")
      Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(service_name: "myallocator_booking_v1")

      expect do
        root_sint.replicator.get_dependent_integration("myallocator_booking_v1")
      end.to raise_error(Webhookdb::InvalidPrecondition, /there are multiple myallocator_booking_v1 integrations/)
    end
  end
end
