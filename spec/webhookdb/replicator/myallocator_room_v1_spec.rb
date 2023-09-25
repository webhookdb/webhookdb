# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorRoomV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root_sint) { fac.create(service_name: "myallocator_root_v1") }
  let(:property_sint) { fac.depending_on(root_sint).create(service_name: "myallocator_property_v1") }
  let(:property_svc) { property_sint.replicator }
  let(:sint) { fac.depending_on(property_sint).create(service_name: "myallocator_room_v1") }
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:get_room_types_request_body) do
    {
      "verb" => "GetRoomTypes",
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "pass1",
      "ota_property_sub_id" => "10034818",
      "mya_property_id" => 1,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
      "RoomInfo" => [
        {
          "mya_room_id" => 45_829,
          "units" => 5,
          "beds" => 2,
          "dormitory" => false,
          "label" => "Double Room",
          "description" => "A potentially long description about the room",
        },
        {
          "mya_room_id" => 290,
          "units" => 25,
          "beds" => 4,
          "dormitory" => false,
          "label" => "4-person private",
          "description" => nil,
        },
      ],
    }
  end

  let(:setup_property_request_body) do
    {
      "verb" => "SetupProperty",
      "ota_property_id" => "",
      "ota_property_password" => "",
      "ota_property_sub_id" => "",
      "mya_property_id" => 1,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
      "RoomInfo" => [
        {
          "mya_room_id" => 45_829,
          "units" => 5,
          "beds" => 2,
          "dormitory" => false,
          "label" => "Double Room",
          "description" => "A potentially long description about the room",
        },
      ],
    }
  end

  let(:create_property_request_body) do
    {
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "pass2",
      "ota_property_sub_id" => "10034818",
      "mya_property_id" => 1,
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
        "rooms" => [
          {
            "mya_room_id" => 45_829,
            "units" => 5,
            "beds" => 2,
            "dormitory" => false,
            "label" => "Double Room",
            "description" => "A potentially long description about the room",
          },
          {
            "mya_room_id" => 290,
            "units" => 25,
            "beds" => 4,
            "dormitory" => false,
            "label" => "4-person private",
            "description" => nil,
          },
        ],
      },
    }
  end

  def insert_property_row(dep_svc)
    dep_svc.admin_dataset do |ds|
      inserted = ds.returning(Sequel.lit("*")).
        insert(
          data: {}.to_json,
          mya_property_id: 1,
          ota_property_id: "ota_prop123",
          ota_property_password: "pass1",
          ota_property_sub_id: "sub1",
        )
      return inserted.first
    end
  end

  it_behaves_like "a replicator", "myallocator_room_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:dep_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:body) { setup_property_request_body }
    let(:request_path) { "/SetupProperty" }
    let(:supports_row_diff) { false }
    let(:fake_request_env) { {"api.request.body" => {}} }
    let(:expected_data) do
      {
        "beds" => 2,
        "label" => "Double Room",
        "units" => 5,
        "dormitory" => false,
        "description" => "A potentially long description about the room",
        "mya_room_id" => 45_829,
        "mya_property_id" => 1,
        "ota_property_id" => "ota_prop123",
        "ota_property_sub_id" => "sub1",
        "ota_property_password" => "pass1",
      }
    end

    def insert_required_data_callback
      return lambda do |dep_svc|
        insert_property_row(dep_svc)
      end
    end
  end

  it_behaves_like "a replicator dependent on another", "myallocator_room_v1",
                  "myallocator_property_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Properties to sync" }
  end

  it_behaves_like "a replicator that processes webhooks synchronously", "myallocator_room_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:dep_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:request_body) { setup_property_request_body }
    let(:request_path) { "/SetupProperty" }
    let(:expected_synchronous_response) do
      "{\"success\":false,\"errors\":[{\"id\":1154,\"msg\":\"No such property\"}]}"
    end
  end

  describe "upsert_webhook" do
    before(:each) do
      org.prepare_database_connections
      property_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "noops if parent property row doesn't exist" do
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: setup_property_request_body, path: "/SetupProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "noops if there is no room information" do
      insert_property_row(property_svc)
      no_rooms_body = setup_property_request_body.dup
      no_rooms_body.delete("RoomInfo")
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: no_rooms_body, path: "/SetupProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "noops if ota credentials are incorrect on 'GetRoomTypes' request" do
      insert_property_row(property_svc)
      bad_cred_body = get_room_types_request_body.merge("ota_property_password" => "bad_pass")
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: bad_cred_body, path: "/GetRoomTypes")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "inserts room objects from 'GetRoomTypes' request" do
      insert_property_row(property_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: get_room_types_request_body, path: "/GetRoomTypes")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(2)
        expect(ds.all).to contain_exactly(
          include(mya_room_id: 45_829, beds: 2, dormitory: false, label: "Double Room"),
          include(mya_room_id: 290, beds: 4, dormitory: false, label: "4-person private"),
        )
      end
    end

    it "inserts room objects from 'SetupProperty' request" do
      insert_property_row(property_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: setup_property_request_body, path: "/SetupProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.all).to contain_exactly(
          include(mya_room_id: 45_829, beds: 2, dormitory: false, label: "Double Room"),
        )
      end
    end

    it "inserts room objects from 'CreateProperty' request" do
      insert_property_row(property_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: create_property_request_body, path: "/CreateProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(2)
        expect(ds.all).to contain_exactly(
          include(mya_room_id: 45_829, beds: 2, dormitory: false, label: "Double Room"),
          include(mya_room_id: 290, beds: 4, dormitory: false, label: "4-person private"),
        )
      end
    end
  end

  describe "synchronous_processing_response_body" do
    before(:each) do
      org.prepare_database_connections
      property_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "returns nil response on 'CreateProperty' request" do
      insert_property_row(property_svc)
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: create_property_request_body,
        method: "POST",
        path: "/CreateProperty",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to be_nil
    end

    it "returns 'success' response on 'SetupProperty' request" do
      insert_property_row(property_svc)
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: setup_property_request_body,
        method: "POST",
        path: "/SetupProperty",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq({"success" => true}.to_json)
    end

    it "returns response with room info on 'GetRoomTypes' request" do
      insert_property_row(property_svc)

      req = Webhookdb::Replicator::WebhookRequest.new(
        body: get_room_types_request_body,
        method: "POST",
        path: "/GetRoomTypes",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      parsed_resp = JSON.parse(synch_resp)
      expect(parsed_resp.fetch("success")).to be true
      expect(parsed_resp.fetch("Rooms")).to contain_exactly(
        include("title" => "Double Room", "occupancy" => 2, "dorm" => false, "ota_room_id" => be_uuid),
        include("title" => "4-person private", "occupancy" => 4, "dorm" => false, "ota_room_id" => be_uuid),
      )
    end

    it "returns error response when parent property row does not exist" do
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: setup_property_request_body,
        method: "POST",
        path: "/SetupProperty",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      expect(inserting).to be_nil

      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq(
        {"success" => false, "errors" => [{"id" => 1154, "msg" => "No such property"}]}.to_json,
      )
    end

    it "returns error response when ota credentials are incorrect" do
      insert_property_row(property_svc)
      bad_cred_body = get_room_types_request_body.merge("ota_property_id" => "wrong_prop_id")
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: bad_cred_body,
        method: "POST",
        path: "/GetRoomTypes",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      expect(inserting).to be_nil

      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq(
        {
          "success" => false,
          "errors" => [{"id" => 1001, "msg" => "Invalid OTA creds for property"}],
        }.to_json,
      )
    end

    it "doesn't return error response when ota credentials are invalid on a `SetupProperty` request" do
      insert_property_row(property_svc)
      bad_cred_body = get_room_types_request_body.merge("ota_property_id" => "wrong_prop_id")
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: bad_cred_body,
        method: "POST",
        path: "/SetupProperty",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq({"success" => true}.to_json)
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
    describe "calculate_webhook_state_machine" do
      it "returns org database info" do
        sint.webhook_secret = "secret"
        sm = svc.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Once data is available, you can query MyAllocator Rooms"),
        )
      end
    end
  end
end
