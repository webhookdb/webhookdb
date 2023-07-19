# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::EmailOctopusContactV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:list_sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: "email_octopus_list_v1",
      organization: org,
      backfill_key: "list_bf_key",
    )
  end
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(
      service_name: "email_octopus_contact_v1",
      organization: org,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  it_behaves_like "a replicator", "email_octopus_contact_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "00000000-0000-0000-0000-000000000000",
          "email_address": "john.doe@example.com",
          "fields": {
            "FirstName": "John",
            "LastName": "Doe",
            "Birthday": "2000-12-20"
          },
          "tags": [
            "vip"
          ],
          "status": "SUBSCRIBED",
          "created_at": "2023-06-29T00:00:00+00:00",#{' '}
          "list_id": "001"
        }
      J
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator dependent on another", "email_octopus_contact_v1",
                  "email_octopus_list_v1" do
    let(:no_dependencies_message) { "This integration requires Email Octopus Lists to sync" }
  end

  it_behaves_like "a replicator that can backfill", "email_octopus_contact_v1" do
    let(:empty_response) do
      <<~R
        {
          "data": [],
          "paging": {
            "previous": null,
            "next": null
          }
        }
      R
    end

    let(:page1_response) do
      <<~R
        {
          "data": [
            {
              "id": "00000000-0000-0000-0000-000000000000",
              "email_address": "john.doe@example.com",
              "fields": {
                "FirstName": "John",
                "LastName": "Doe",
                "Birthday": "2000-12-20"
              },
              "tags": [
                "vip"
              ],
              "status": "SUBSCRIBED",
              "created_at": "2023-06-29T00:00:00+00:00"
            }
          ],
          "paging": {
            "next": "/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100&page=2",
            "previous": null
          }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "data": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "email_address": "jane.doe@example.com",
              "fields": {
                "FirstName": "Jane",
                "LastName": "Doe",
                "Birthday": "2000-12-20"
              },
              "tags": [
                "vip"
              ],
              "status": "SUBSCRIBED",
              "created_at": "2023-06-29T00:00:00+00:00"
            }
          ],
          "paging": {
            "next": null,
            "previous": "/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100"
          }
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "data": [
            {
              "id": "00000000-0000-0000-0000-000000000002",
              "email_address": "jack.doe@example.com",
              "fields": {
                "FirstName": "Jack",
                "LastName": "Doe",
                "Birthday": "2008-12-12"
              },
              "tags": [
                "vip"
              ],
              "status": "SUBSCRIBED",
              "created_at": "2023-06-29T00:00:00+00:00"
            }
          ],
          "paging": {
            "next": null,
            "previous": null
          }
        }
      R
    end
    let(:expected_items_count) { 3 }

    def insert_required_data_callback
      return lambda do |list_svc|
        list_svc.service_integration.update(backfill_key: "list_bf_key")
        list_svc.admin_dataset do |list_ds|
          list_ds.multi_insert(
            [
              {
                email_octopus_id: "000",
                name: "List 1",
                created_at: "2023-06-28T17:00:24+00:00",
                pending: 0,
                subscribed: 1,
                unsubscribed: 0,
                data: "{}",
              },
              {
                email_octopus_id: "001",
                name: "List 2",
                created_at: "2023-06-28T17:00:24+00:00",
                pending: 0,
                subscribed: 1,
                unsubscribed: 0,
                data: "{}",
              },
            ],
          )
        end
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100&page=2").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/lists/001/contacts?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://emailoctopus.com/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100").
          to_return(status: 403)
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/lists/000/contacts?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/lists/001/contacts?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  describe "getting credentials from dependency" do
    it "raises err if credentials are not set on list replicator" do
      err_msg = "This integration requires that the Email Octopus List integration has a valid API Key"
      sint.depends_on.update(backfill_key: "")
      expect do
        backfill(sint)
      end.to raise_error(Webhookdb::Replicator::CredentialsMissing).with_message(err_msg)
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "email_octopus_contact_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      status, headers, body = svc.webhook_response(fake_request).to_rack
      expect(status).to eq(401)
      expect(body).to include("missing signature")
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "secureuser:pass")
      req = fake_request
      data = req.body
      calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", "bad", data))
      req.add_header("HTTP_EMAILOCTOPUS_SIGNATURE", calculated_hmac)
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("invalid signature")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "56f1b498b4c692b390fcc17d00fa79148495975721312def0e4a10f07fe3a028")
      # rubocop:disable Layout/LineLength
      body = '[{"id":"64a53baf-f9c5-4fa7-84b8-de05af070554","type":"contact.updated","list_id":"8f7c154e-0adc-11ee-acf6-b3c282ea3783","contact_id":"076669e8-1d06-11ee-b055-07ca0addb982","occurred_at":"2023-07-10T17:16:39+00:00","contact_fields":{"LastName":"Rodriguez","FirstName":"Miller"},"contact_status":"SUBSCRIBED","contact_email_address":"Miller@example.com"}]'
      # rubocop:enable Layout/LineLength
      req = fake_request(input: body)
      req.add_header(
        "HTTP_EMAILOCTOPUS_SIGNATURE",
        "sha256=8e448d6c3a8b01ac6626f70b4a531d184e327f1d45ebecec1750b8086d7908f1",
      )
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "upsert_webhook" do
    Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    def insert_contact_row
      svc.admin_dataset do |ds|
        ds.insert(
          compound_identity: "contact_id-list_id",
          created_at: Time.parse("2022-10-18T15:20:23+00:00"),
          deleted_at: nil,
          email_address: "claire@example.com",
          email_octopus_id: "contact_id",
          email_octopus_list_id: "list_id",
          status: "SUBSCRIBED",
          data: "{}",
        )
      end
    end

    it "upserts a 'contact.created' event with `created_at` value" do
      body = [{
        "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
        "type" => "contact.created",
        "list_id" => "list_id",
        "contact_id" => "contact_id",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Claire",
        },
        "contact_status" => "SUBSCRIBED",
        "contact_email_address" => "claire@example.com",
        "contact_tags" => ["vip"],
      }]

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(
          created_at: match_time("2022-11-18T15:20:23+00:00"),
          deleted_at: nil,
          email_address: "claire@example.com",
          email_octopus_id: "contact_id",
          email_octopus_list_id: "list_id",
          status: "SUBSCRIBED",
        )
      end
    end

    it "upserts a 'contact.deleted' event with `deleted_at` value" do
      body = [{
        "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
        "type" => "contact.deleted",
        "list_id" => "list_id",
        "contact_id" => "contact_id",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Claire",
        },
        "contact_status" => "UNSUBSCRIBED",
        "contact_email_address" => "claire@example.com",
        "contact_tags" => ["vip"],
      }]

      insert_contact_row
      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(
          created_at: match_time("2022-10-18T15:20:23+00:00"),
          deleted_at: match_time("2022-11-18T15:20:23+00:00"),
          email_address: "claire@example.com",
          email_octopus_id: "contact_id",
          email_octopus_list_id: "list_id",
          status: "UNSUBSCRIBED",
        )
      end
    end

    it "transforms a 'contact.updated' event" do
      body = [{
        "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
        "type" => "contact.updated",
        "list_id" => "list_id",
        "contact_id" => "contact_id",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Claire",
        },
        "contact_status" => "UNSUBSCRIBED",
        "contact_email_address" => "claire2@example.com",
        "contact_tags" => ["vip"],
      }]

      insert_contact_row
      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(
          created_at: match_time("2022-10-18T15:20:23+00:00"),
          deleted_at: nil,
          email_octopus_id: "contact_id",
          email_address: "claire2@example.com",
          email_octopus_list_id: "list_id",
          status: "UNSUBSCRIBED",
        )
      end
    end

    it "upserts multiple webhook bodies" do
      body = [{
        "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
        "type" => "contact.created",
        "list_id" => "list_id",
        "contact_id" => "contact_id",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Claire",
        },
        "contact_status" => "SUBSCRIBED",
        "contact_email_address" => "claire@example.com",
        "contact_tags" => ["vip"],
      }, {
        "id" => "42636763-73f9-463e-af8b-3f720bb3d888",
        "type" => "contact.created",
        "list_id" => "list_id",
        "contact_id" => "contact_id_2",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Delia",
        },
        "contact_status" => "SUBSCRIBED",
        "contact_email_address" => "delia@example.com",
        "contact_tags" => ["vip"],
      }, {
        "id" => "42636763-73f9-463e-af8b-3f720bb3d887",
        "type" => "contact.created",
        "list_id" => "list_id",
        "contact_id" => "contact_id_3",
        "occurred_at" => "2022-11-18T15:20:23+00:00",
        "contact_fields" => {
          "LastName" => "Example",
          "FirstName" => "Edna",
        },
        "contact_status" => "SUBSCRIBED",
        "contact_email_address" => "edna@example.com",
        "contact_tags" => ["vip"],
      },]

      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(3)
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      before(:each) do
        sint.update(webhook_secret: "")
      end

      it "asks for webhook secret" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your webhook secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: false,
          output: match(/You are about to start replicating Email Octopus Contacts/),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "whsek"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match(/Great! WebhookDB is now listening for Email Octopus Contact webhooks/),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      let(:success_body) do
        <<~R
          {
            "data": [],
            "paging": {}
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://emailoctopus.com/api/1.6/lists?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: success_body, headers: {"Content-Type" => "application/json"})
      end

      it "returns org database info" do
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start replicating your Email Octopus Contacts."),
        )
      end
    end
  end
end
