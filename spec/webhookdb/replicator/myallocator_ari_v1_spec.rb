# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorAriV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root_sint) { fac.create(service_name: "myallocator_root_v1") }
  let(:property_sint) { fac.depending_on(root_sint).create(service_name: "myallocator_property_v1") }
  let(:property_svc) { property_sint.replicator }
  let(:sint) { fac.depending_on(property_sint).create(service_name: "myallocator_ari_v1") }
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:ari_update_request_body) do
    {
      "verb" => "ARIUpdate",
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "pass1",
      "ota_property_sub_id" => "sub1",
      "mya_property_id" => 1,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "currency" => "USD",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
      "Inventory" => [
        {
          "ota_room_id" => "61365",
          "ota_rate_id" => "rate_456",
          "start_date" => "2025-01-22",
          "end_date" => "2025-01-24",
          "units" => 5,
          "rate" => "15.00",
          "rdef_single" => "2.00",
          "max_los" => 14,
          "min_los" => 2,
          "closearr" => false,
          "closedep" => false,
          "close" => false,
        },
        {
          "ota_room_id" => "61365",
          "ota_rate_id" => "rate_888",
          "start_date" => "2025-02-11",
          "end_date" => "2025-02-12",
          "units" => 5,
          "rate" => "30.00",
          "close" => true,
        },
      ],
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

  it_behaves_like "a replicator", "myallocator_ari_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:dep_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:body) do
      ari_update_request_body.merge(
        {"Inventory" => [
          {
            "ota_room_id" => "61365",
            "ota_rate_id" => "rate_456",
            "start_date" => "2025-01-22",
            "end_date" => "2025-01-22",
            "units" => 5,
            "rate" => "15.00",
            "rdef_single" => "2.00",
            "max_los" => 14,
            "min_los" => 2,
            "closearr" => false,
            "closedep" => false,
            "close" => false,
          },
        ]},
      )
    end
    let(:request_path) { "/ARIUpdate" }
    let(:supports_row_diff) { false }
    let(:fake_request_env) { {"api.request.body" => {}} }
    let(:expected_data) do
      {"date" => "2025-01-22",
       "rate" => "15.00",
       "close" => false,
       "units" => 5,
       "max_los" => 14,
       "min_los" => 2,
       "closearr" => false,
       "closedep" => false,
       "ota_rate_id" => "rate_456",
       "ota_room_id" => "61365",
       "rdef_single" => "2.00",
       "mya_property_id" => 1,
       "ota_property_id" => "ota_prop123",
       "ota_property_sub_id" => "sub1",}
    end

    def insert_required_data_callback
      return lambda do |dep_svc|
        insert_property_row(dep_svc)
      end
    end
  end

  it_behaves_like "a replicator dependent on another", "myallocator_ari_v1",
                  "myallocator_property_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Properties to sync" }
  end

  it_behaves_like "a replicator that processes webhooks synchronously", "myallocator_ari_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:dep_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:request_body) { ari_update_request_body }
    let(:request_path) { "/ARIUpdate" }
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
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: ari_update_request_body, path: "/ARIUpdate")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "noops if ota credentials are incorrect" do
      insert_property_row(property_svc)
      bad_cred_body = ari_update_request_body.merge("ota_property_password" => "bad_pass")
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: bad_cred_body, path: "/ARIUpdate")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "inserts inventory objects" do
      insert_property_row(property_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: ari_update_request_body, path: "/ARIUpdate")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(5)
        expect(ds.all).to contain_exactly(
          include(ota_room_id: "61365", ota_rate_id: "rate_456", date: Date.new(2025, 1, 22)),
          include(ota_room_id: "61365", ota_rate_id: "rate_456", date: Date.new(2025, 1, 23)),
          include(ota_room_id: "61365", ota_rate_id: "rate_456", date: Date.new(2025, 1, 24)),
          include(ota_room_id: "61365", ota_rate_id: "rate_888", date: Date.new(2025, 2, 11)),
          include(ota_room_id: "61365", ota_rate_id: "rate_888", date: Date.new(2025, 2, 12)),
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

    it "returns 'success' response" do
      insert_property_row(property_svc)
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: ari_update_request_body,
        method: "POST",
        path: "/ARIUpdate",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq({"success" => true}.to_json)
    end

    it "returns error response when parent property row does not exist" do
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: ari_update_request_body,
        method: "POST",
        path: "/ARIUpdate",
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
      bad_cred_body = ari_update_request_body.merge("ota_property_id" => "wrong_prop_id")
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: bad_cred_body,
        method: "POST",
        path: "/ARIUpdate",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      expect(inserting).to be_nil

      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to eq(
        {"success" => false,
         "errors" => [{"id" => 1001, "msg" => "Invalid OTA creds for property"}],}.to_json,
      )
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
          output: match("Once data is available, you can query MyAllocator Inventory"),
        )
      end
    end
  end
end
