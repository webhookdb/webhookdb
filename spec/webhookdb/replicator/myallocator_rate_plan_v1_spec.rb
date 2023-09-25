# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorRatePlanV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:root_sint) { fac.create(service_name: "myallocator_root_v1") }
  let(:property_sint) { fac.depending_on(root_sint).create(service_name: "myallocator_property_v1") }
  let(:property_svc) { Webhookdb::Replicator.create(property_sint) }
  let(:room_sint) { fac.depending_on(property_sint).create(service_name: "myallocator_room_v1") }
  let(:room_svc) { Webhookdb::Replicator.create(room_sint) }
  let(:sint) { fac.depending_on(room_sint).create(service_name: "myallocator_rate_plan_v1") }
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:create_property_request_body) do
    {

      "mya_property_id" => 1,
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "pass1",
      "ota_property_sub_id" => "sub1",
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
        "weekend" => [
          "tuesday",
          "saturday",
          "sunday",
        ],
        "firstname" => "John",
        "lastname" => "Smith",
        "timezone" => "Asia/Thimphu",
        "address" => {
          "address_line_1" => "Main St",
          "address_line_2" => "Annex",
          "city" => "San Diego",
          "zip" => "92120",
          "state" => "CA",
          "country" => "US",
          "website" => "http =>//example.com",
          "lon" => "32.715736",
          "lat" => "-117.161087",
          "phone" => "+1 123123123 ",
          "fax" => "+1 123123123",
        },
        "business_contact" => {
          "main_contact_name" => "Jeff Johnson",
          "company_name" => "Hostels Inc.",
          "account_manager_name" => "Hillary Jackson",
          "vat_id" => "US2345678",
          "address_line_1" => "Office Street",
          "address_line_2" => "3rd floor",
          "state" => "Office State",
          "zip" => "22222",
          "city" => "Office City",
          "country" => "DE",
        },
        "images" => [
          {
            "url" => "https =>//inbox.myallocator.com/n/user_image.xt?pid=1&img=97f471e5-5898-4e9a-ab37.jpg",
            "description" => "Outside View",
            "sort_order" => 1,
          },
          {
            "url" => "https =>//inbox.myallocator.com/n/user_image.xt?pid=1&img=97f471e5-5898-4e9a-9c38.jpg",
            "description" => "Reception Area",
            "sort_order" => 2,
          },
        ],
        "rooms" => [
          {
            "mya_room_id" => 290,
            "units" => 25,
            "beds" => 4,
            "dormitory" => false,
            "label" => "4-person private",
            "description" => nil,
            "images" => [],
            "rateplans" => [
              {
                "label_private" => "Default Rate Plan",
                "label_public" => "Default Rate Plan",
                "mya_rate_id" => 0,
              },
            ],
          },
          {
            "mya_room_id" => 329,
            "units" => 7,
            "beds" => 3,
            "dormitory" => false,
            "label" => "3-person private",
            "description" => "Best three bed room in town",
            "images" => [
              {
                "url" => "https =>//inbox.myallocator.com/n/user_image.xt?pid=1&img=97f471e5-5898-4e9a-ab37.jpg",
                "description" => "3-bed room",
                "sort_order" => 1,
              },
            ],
            "rateplans" => [
              {
                "label_public" => "Default Rate Plan",
                "label_private" => "Default Rate Plan",
                "mya_rate_id" => 0,
              },
              {
                "mya_rate_id" => 853,
                "label_private" => "NR",
                "label_public" => "Non-refundable",
              },
            ],
          },
        ],
      },
    }
  end

  let(:get_rate_plans_request_body) do
    {
      "verb" => "GetRatePlans",
      "mya_property_id" => 1,
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "pass1",
      "ota_property_sub_id" => "sub1",
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
    }
  end

  def insert_property_row(prop_svc)
    prop_svc.admin_dataset do |ds|
      inserted = ds.returning(Sequel.lit("*")).
        insert(
          data: {}.to_json,
          mya_property_id: 1,
          ota_property_id: "ota_prop123",
          ota_property_password: "pass1",
          ota_property_sub_id: "sub1",
          name: "cool property",
        )
      return inserted.first
    end
  end

  def insert_room_rows(rm_svc)
    rm_svc.admin_dataset do |ds|
      ds.multi_insert(
        [
          {mya_room_id: 329, ota_room_id: "room 1", data: "{}"},
          {mya_room_id: 290, ota_room_id: "room 2", data: "{}"},
        ],
      )
    end
  end

  it_behaves_like "a replicator", "myallocator_rate_plan_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:prop_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:room_sint) do
      Webhookdb::Fixtures.service_integration.depending_on(property_sint).create(
        service_name: "myallocator_room_v1",
        organization: org,
        )
    end
    let(:sint) do
      Webhookdb::Fixtures.service_integration.depending_on(room_sint).create(
        service_name: "myallocator_rate_plan_v1",
        organization: org,
        )
    end
    let(:body) do
      {
        "ota_property_id" => "ota_prop123",
        "ota_property_sub_id" => "sub1",
        "ota_property_password" => "pass1",
        "mya_property_id" => 1,
        "ota_cid" => "ota",
        "verb" => "CreateProperty",
        "shared_secret" => "s3cr3ts4uc3",
        "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
        "Property" => {
          "name" => "Sample Hostel",
          "rooms" => [
            {
              "mya_room_id" => 329,
              "units" => 7,
              "beds" => 3,
              "dormitory" => false,
              "label" => "3-person private",
              "description" => "Best three bed room in town",
              "images" => [
                {
                  "url" => "https =>//inbox.myallocator.com/n/user_image.xt?pid=1&img=97f471e5-5898-4e9a-ab37.jpg",
                  "description" => "3-bed room",
                  "sort_order" => 1,
                },
              ],
              "rateplans" => [
                {
                  "label_public" => "Default Rate Plan",
                  "label_private" => "Default Rate Plan",
                  "mya_rate_id" => 0,
                },
              ],
            },
          ],
        },
      }
    end
    let(:request_path) { "/CreateProperty" }
    let(:supports_row_diff) { false }
    let(:fake_request_env) { {"api.request.body" => {}} }
    let(:expected_data) do
      {

        "label_public" => "Default Rate Plan",
        "label_private" => "Default Rate Plan",
        "mya_rate_id" => 0,
        "mya_room_id" => 329,
        "mya_property_id" => 1,
        "ota_room_id" => "room 1",
        "ota_property_id" => "ota_prop123",
        "ota_property_sub_id" => "sub1",
        "ota_property_password" => "pass1",
      }
    end

    def insert_required_data_callback
      return lambda do |room_svc, property_svc, _root_svc|
        property_svc.create_table
        insert_property_row(property_svc)
        insert_room_rows(room_svc)
      end
    end
  end

  it_behaves_like "a replicator dependent on another", "myallocator_rate_plan_v1",
                  "myallocator_room_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Rooms to sync" }
  end

  it_behaves_like "a replicator that processes webhooks synchronously", "myallocator_rate_plan_v1" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:dep_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_property_v1", organization: org)
    end
    let(:request_body) { get_rate_plans_request_body }
    let(:request_path) { "/GetRatePlans" }
    let(:expected_synchronous_response) do
      "{\"success\":false,\"errors\":[{\"id\":1154,\"msg\":\"No such property\"}]}"
    end
  end

  describe "upsert_webhook" do
    before(:each) do
      org.prepare_database_connections
      property_svc.create_table
      room_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "noops if parent property row doesn't exist" do
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: create_property_request_body, path: "/CreateProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "noops for requests that aren't `CreateProperty` requests" do
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: get_rate_plans_request_body, path: "/GetRatePlans")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(0) }
    end

    it "raises error if parent room rows don't exist" do
      insert_property_row(property_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: create_property_request_body, path: "/CreateProperty")
      expect do
        svc.upsert_webhook(whreq)
      end.to raise_error(Webhookdb::InvalidPostcondition, "there is no room with myallocator id 290")
    end

    it "inserts 'RatePlans' objects as individual rows" do
      insert_property_row(property_svc)
      insert_room_rows(room_svc)
      whreq = Webhookdb::Replicator::WebhookRequest.new(body: create_property_request_body, path: "/CreateProperty")
      svc.upsert_webhook(whreq)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(3)
        expect(ds.all).to contain_exactly(
          include(
            label_private: "Default Rate Plan",
            label_public: "Default Rate Plan",
            mya_rate_id: 0,
            mya_room_id: 290,
            ota_rate_id: be_uuid,
          ),
          include(
            label_private: "Default Rate Plan",
            label_public: "Default Rate Plan",
            mya_rate_id: 0,
            mya_room_id: 329,
            ota_rate_id: be_uuid,
          ),
          include(
            label_private: "NR",
            label_public: "Non-refundable",
            mya_room_id: 329,
            mya_rate_id: 853,
            ota_rate_id: be_uuid,
          ),
        )
      end
    end
  end

  describe "synchronous_processing_response_body" do
    before(:each) do
      org.prepare_database_connections
      property_svc.create_table
      room_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "returns expected response on 'GetRatePlans' request" do
      insert_property_row(property_svc)
      svc.admin_dataset do |ds|
        ds.multi_insert(
          [
            {
              compound_identity: "11-0",
              data: "{}",
              label_public: "rate 1",
              mya_property_id: 1,
              mya_rate_id: 0,
              mya_room_id: 11,
              ota_property_id: "ota_prop123",
              ota_property_password: "pass1",
              ota_property_sub_id: "sub1",
              ota_rate_id: "rate uuid 1",
              ota_room_id: "room uuid 1",
            },
            {
              compound_identity: "11-3",
              data: "{}",
              label_public: "rate 2",
              mya_property_id: 1,
              mya_rate_id: 3,
              mya_room_id: 11,
              ota_property_id: "ota_prop123",
              ota_property_password: "pass1",
              ota_property_sub_id: "sub1",
              ota_rate_id: "rate uuid 2",
              ota_room_id: "room uuid 2",
            },
          ],
        )
      end

      req = Webhookdb::Replicator::WebhookRequest.new(
        body: get_rate_plans_request_body,
        method: "POST",
        path: "/GetRatePlans",
      )
      synch_resp = svc.synchronous_processing_response_body(upserted: nil, request: req)
      parsed_resp = JSON.parse(synch_resp)
      expect(parsed_resp.fetch("success")).to be true
      expect(parsed_resp.fetch("RatePlans")).to contain_exactly(
        include("title" => "rate 1", "ota_room_id" => "room uuid 1", "ota_rate_id" => "rate uuid 1"),
        include("title" => "rate 2", "ota_room_id" => "room uuid 2", "ota_rate_id" => "rate uuid 2"),
      )
    end

    it "returns error response when parent property row does not exist" do
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: get_rate_plans_request_body,
        method: "POST",
        path: "/GetRatePlans",
      )
      synch_resp = svc.synchronous_processing_response_body(upserted: nil, request: req)
      expect(synch_resp).to eq(
        {"success" => false, "errors" => [{"id" => 1154, "msg" => "No such property"}]}.to_json,
      )
    end

    it "returns error response when ota credentials are incorrect" do
      insert_property_row(property_svc)
      bad_cred_body = get_rate_plans_request_body.merge("ota_property_id" => "wrong_prop_id")
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: bad_cred_body,
        method: "POST",
        path: "/GetRatePlans",
      )

      synch_resp = svc.synchronous_processing_response_body(upserted: nil, request: req)
      expect(synch_resp).to eq(
        {
          "success" => false,
          "errors" => [{"id" => 1001, "msg" => "Invalid OTA creds for property"}],
        }.to_json,
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
          output: match("Once data is available, you can query MyAllocator Rate Plans"),
        )
      end
    end
  end
end
