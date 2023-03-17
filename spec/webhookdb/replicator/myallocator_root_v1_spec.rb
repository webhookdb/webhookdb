# frozen_string_literal: true

require "support/shared_examples_for_replicators"
require "rack"

RSpec.describe Webhookdb::Replicator::MyallocatorRootV1, :db do
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1", backfill_key: "api_key")
  end
  let(:svc) { sint.replicator }

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
      sint.replicator.backfill
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
    let(:svc) { root_sint.replicator }
    let(:fac) { Webhookdb::Fixtures.service_integration.depending_on(root_sint) }

    def request_to(uri)
      env = Rack::MockRequest.env_for(uri)
      return fake_request(env:)
    end

    it "dispatches appropriate requests to booking sint" do
      booking_sint = fac.create(service_name: "myallocator_booking_v1")

      booking_create_req = request_to("http://example.com/BookingCreate")
      expect(svc.dispatch_request_to(booking_create_req).service_integration).to eq(booking_sint)
      booking_list_req = request_to("http://example.com/GetBookingList")
      expect(svc.dispatch_request_to(booking_list_req).service_integration).to eq(booking_sint)
      booking_detail_req = request_to("http://example.com/GetBookingId")
      expect(svc.dispatch_request_to(booking_detail_req).service_integration).to eq(booking_sint)
    end

    it "raises RuntimeError when url is not handled by case statement" do
      expect { svc.dispatch_request_to(fake_request) }.to raise_error(RuntimeError, /invalid path/)
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
