# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MyallocatorBookingV1, :db do
  let(:root_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "myallocator_root_v1") }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(root_sint).create(service_name: "myallocator_booking_v1")
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  let(:booking_create_request_body) do
    {"mya_property_id" => 998_201,
     "shared_secret" => "s3cr3ts4uc3",
     "booking_json" =>
       {"OrderId" => "123456789",
        "OrderDate" => "2018-04-22",
        "OrderTime" => "18:02:58",
        "IsCancellation" => 0,
        "TotalCurrency" => "USD",
        "TotalPrice" => 134,
        "Customers" => [
          {"CustomerCountry" => "US",
           "CustomerEmail" => "test@test.com",
           "CustomerFName" => "Test Firstname",
           "CustomerLName" => "Test Lastname",},
        ],
        "Rooms" => [
          {"ChannelRoomType" => "abcdef",
           "Currency" => "USD",
           "DayRates" => [
             {"Date" => "2017-11-08",
              "Description" => "Refundable Rate",
              "Rate" => 32.5,
              "Currency" => "USD",
              "RateId" => "13649",},
             {"Date" => "2017-11-09",
              "Description" => "Refundable Rate",
              "Rate" => 34.5,
              "Currency" => "USD",
              "RateId" => "13649",},
           ],
           "StartDate" => "2017-11-08",
           "EndDate" => "2017-11-09",
           "Price" => 134,
           "Units" => 2,},
        ],},
     "booking_id" => "booking_abc",
     "ota_property_id" => "ota_prop",
     "ota_property_sub_id" => "",
    }
  end
  let(:get_booking_id_request_body) do
    {
      "verb" => "GetBookingId",
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "very-secret-password",
      "ota_property_sub_id" => "sub2",
      "mya_property_id" => 1,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
      "booking_id" => "booking_ghi",
    }
  end
  let(:get_booking_list_request_body) do
    {
      "verb" => "GetBookingList",
      "ota_property_id" => "ota_prop123",
      "ota_property_password" => "very-secret-password",
      "ota_property_sub_id" => "sub2",
      "mya_property_id" => 1,
      "guid" => "6C08B96E-450D-4E6A-9933-7D0305730305",
      "ota_cid" => "ota",
      "shared_secret" => "s3cr3ts4uc3",
      "ota_booking_version" => "2022-03-22 12:09:19",
    }
  end

  def insert_booking_rows
    svc.admin_dataset do |ds|
      ds.multi_insert(
        [
          {
            data: {},
            booking_id: "booking_abc",
            mya_property_id: 1,
            ota_property_id: "ota_prop123",
            ota_property_sub_id: "sub1",
          },
          {
            data: {},
            booking_id: "booking_def",
            mya_property_id: 1,
            ota_property_id: "ota_prop123",
            ota_property_sub_id: "sub2",
          },
          {
            data: {foo: "bar"},
            booking_id: "booking_ghi",
            mya_property_id: 1,
            ota_property_id: "ota_prop123",
            ota_property_sub_id: "sub2",
          },
        ],
      )
    end
  end

  it_behaves_like "a replicator", "myallocator_booking_v1" do
    let(:body) { booking_create_request_body }
    let(:request_path) { "/BookingCreate" }
    let(:request_method) { "POST" }
    let(:supports_row_diff) { false }
  end
  it_behaves_like "a replicator dependent on another", "myallocator_booking_v1",
                  "myallocator_root_v1" do
    let(:no_dependencies_message) { "This integration requires MyAllocator Root to sync" }
  end

  it_behaves_like "a replicator that processes webhooks synchronously", "myallocator_booking_v1" do
    let(:request_body) { booking_create_request_body }
    let(:request_path) { "/BookingCreate" }
    let(:request_method) { "PUT" }
    let(:expected_synchronous_response) { nil }
  end

  describe "synchronous_processing_response_body" do
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "returns expected response on 'BookingCreate' request" do
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: booking_create_request_body,
        method: "POST",
        path: "/BookingCreate",
      )
      inserting = svc.upsert_webhook(req)
      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(synch_resp).to be_nil
    end

    it "returns expected response on 'GetBookingId' request" do
      insert_booking_rows
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: get_booking_id_request_body,
        method: "POST",
        path: "/GetBookingId",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      expect(inserting).to be_nil

      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq(
        {
          "success" => true,
          "Booking" => {foo: "bar"},
        },
      )
    end

    it "returns expected response on 'GetBookingList' request" do
      insert_booking_rows
      req = Webhookdb::Replicator::WebhookRequest.new(
        body: get_booking_id_request_body,
        method: "POST",
        path: "/GetBookingId",
      )
      # upsert_webhook should noop here
      inserting = svc.upsert_webhook(req)
      expect(inserting).to be_nil

      synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: req)
      expect(JSON.parse(synch_resp)).to eq(
        {
          "success" => true,
          "Bookings" => [{booking_id: "booking_def"}, {booking_id: "booking_ghi"}],
        },
      )
    end
  end

  describe "webhook validation" do
    it "returns a 200 with designated MyAllocator error body if no shared secret" do
      status, headers, body = svc.webhook_response(fake_request).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid credentials"}.to_json)
    end

    it "returns a 200 with designated MyAllocator error body for invalid shared secret" do
      sint.update(webhook_secret: "shared_secret")
      req = fake_request(input: {shared_secret: "shared_secret"}.to_json)
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(200)
      expect(body).to match({"ErrorCode" => 1153, "Error" => "Invalid credentials"}.to_json)
    end

    it "returns a 200 with a valid shared secret" do
      sint.update(webhook_secret: "shared_secret")
      req = fake_request(input: {shared_secret: "shared_secret"}.to_json)
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
          output: match("Once data is available, you can query MyAllocator Bookings"),
        )
      end
    end
  end
end
