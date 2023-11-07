# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::EmailOctopusEventV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:list_sint) do
    Webhookdb::Fixtures.service_integration.create(service_name: "email_octopus_list_v1", organization: org)
  end
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(
      service_name: "email_octopus_event_v1",
      organization: org,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:campaign_sint) do
    Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(
      service_name: "email_octopus_campaign_v1",
      organization: org,
    )
  end
  let(:contact_sint) do
    Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(
      service_name: "email_octopus_contact_v1",
      organization: org,
    )
  end
  let(:contact_svc) { Webhookdb::Replicator.create(contact_sint) }

  it_behaves_like "a replicator", "email_octopus_event_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "contact": {
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
            "created_at": "2023-07-05T00:00:00+00:00"
          },
          "occurred_at": "2023-07-05T17:55:04+00:00",
          "event_type": "opened",
          "campaign_id": "campaign_1"
        }
      J
    end
  end

  it_behaves_like "a replicator dependent on another", "email_octopus_event_v1",
                  "email_octopus_list_v1" do
    let(:no_dependencies_message) { "This integration requires Email Octopus Lists to sync" }
  end

  it_behaves_like "a replicator that can backfill", "email_octopus_event_v1" do
    let(:empty_response) do
      <<~R
        {
          "data": [],
          "paging": []
        }
      R
    end

    let(:campaign_1_complained_response_page1) do
      <<~R
        {
          "data": [
            {
              "contact": {
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
                "created_at": "2023-07-05T00:00:00+00:00"
              },
              "occurred_at": "2023-07-05T17:55:04+00:00"
            }
          ],
          "paging": {
            "next": "/api/1.6/campaigns/1/reports/complained?api_key=list_bf_key&limit=100&page=2"
          }
        }
      R
    end
    let(:campaign_1_complained_response_page2) do
      <<~R
        {
          "data": [
            {
              "contact": {
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
                "created_at": "2023-07-05T00:00:00+00:00"
              },
              "occurred_at": "2023-07-05T17:55:04+00:00"
            }
          ],
          "paging": {
            "next": null
          }
        }
      R
    end
    let(:campaign_2_unsubscribed_response) do
      <<~R
        {
          "data": [
            {
              "contact": {
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
                "status": "UNSUBSCRIBED",
                "created_at": "2023-07-05T00:00:00+00:00"
              },
              "occurred_at": "2023-07-05T19:57:40+00:00"
            }
          ],
          "paging": {
            "next": null
          }
        }
      R
    end

    let(:expected_items_count) { 3 }

    def insert_required_data_callback
      return lambda do |list_svc|
        # The event replicator depends on the list replicator but uses information from the campaign replicator,
        # which also depends on the list replicator. In the code itself it's not too much trouble to climb up
        # and down the dependency tree, but it means that the setup for these tests is a little convoluted.
        list_sint = list_svc.service_integration
        list_sint.update(backfill_key: "list_bf_key")
        campaign_sint = Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(
          service_name: "email_octopus_campaign_v1",
          organization: list_sint.organization,
        )
        campaign_svc = campaign_sint.replicator
        campaign_svc.create_table
        campaign_svc.admin_dataset do |campaign_ds|
          campaign_ds.multi_insert(
            [
              {
                email_octopus_id: "1",
                name: "Campaign 1",
                created_at: "2023-06-28T17:00:24+00:00",
                sent_at: "2023-06-29T17:00:24+00:00",
                status: "SENT",
                from_name: "Nostradamus",
                from_email_address: "nostradamus@example.com",
                subject: "Your Future",
                data: "{}",
              },
              {
                email_octopus_id: "2",
                name: "Campaign 2",
                created_at: "2023-06-30T17:00:24+00:00",
                sent_at: "2023-07-01T17:00:24+00:00",
                status: "SENT",
                from_name: "Herodotus",
                from_email_address: "herodotus@example.com",
                subject: "Your Past",
                data: "{}",
              },
            ],
          )
        end
      end
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/clicked?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=list_bf_key&limit=100").
            to_return(
              status: 200,
              body: campaign_1_complained_response_page1,
              headers: {"Content-Type" => "application/json"},
            ),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=list_bf_key&limit=100&page=2").
            to_return(
              status: 200,
              body: campaign_1_complained_response_page2,
              headers: {"Content-Type" => "application/json"},
            ),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/opened?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/unsubscribed?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/bounced?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/clicked?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/complained?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/opened?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/unsubscribed?api_key=list_bf_key&limit=100").
            to_return(
              status: 200,
              body: campaign_2_unsubscribed_response,
              headers: {"Content-Type" => "application/json"},
            ),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=list_bf_key&limit=100").
          to_return(status: 403)
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/clicked?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/opened?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/unsubscribed?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/bounced?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/clicked?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/complained?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/opened?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/unsubscribed?api_key=list_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  describe "getting credentials from dependency" do
    it "raises err if credentials are not set on list replicator" do
      err_msg = "This integration requires that the email_octopus_list_v1 integration has a valid API Key"
      sint.depends_on.update(backfill_key: "")
      expect do
        backfill(sint)
      end.to raise_error(Webhookdb::Replicator::CredentialsMissing).with_message(err_msg)
    end
  end

  describe "webhook validation" do
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

    let(:event_webhooks) do
      [{"id" => "cd7b763b-c4cb-4dd7-ad0e-f7ed650faa28",
        "type" => "contact.unsubscribed",
        "list_id" => "8f7c154e-0adc-11ee-acf6-b3c282ea3783",
        "contact_id" => "contact_1",
        "occurred_at" => "2023-07-22T18:40:21+00:00",
        "contact_fields" => {"LastName" => "Edson",
                             "FirstName" => "Natalie",},
        "contact_status" => "UNSUBSCRIBED",
        "contact_email_address" => "Natalie@example.com",},
       {"id" => "b8a98439-6f46-40a5-ba11-24589ed9fc82",
        "type" => "contact.bounced",
        "list_id" => "8f7c154e-0adc-11ee-acf6-b3c282ea3783",
        "contact_id" => "contact_1",
        "campaign_id" => "campaign_id",
        "occurred_at" => "2023-07-22T18:40:05+00:00",
        "contact_email_address" => "Natalie@example.com",},]
    end

    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
      contact_sint.replicator.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    def insert_contact_row(contact_id, **more)
      contact_svc.admin_dataset do |ds|
        ds.insert(
          compound_identity: "#{contact_id}-list_id",
          created_at: Time.parse("2022-10-18T15:20:23+00:00"),
          deleted_at: nil,
          email_address: "#{contact_id}@example.com",
          email_octopus_id: contact_id,
          email_octopus_list_id: "list_id",
          status: "SUBSCRIBED",
          data: "{}",
          **more,
        )
      end
    end

    it "upserts multiple webhook bodies" do
      upsert_webhook(svc, body: event_webhooks)
      svc.readonly_dataset do |ds|
        expect(ds.all).to contain_exactly(
          include(
            email_octopus_contact_id: "contact_1",
            email_octopus_campaign_id: "campaign_id",
            event_type: "contact.bounced",
          ),
          include(
            email_octopus_contact_id: "contact_1",
            email_octopus_campaign_id: nil,
            event_type: "contact.unsubscribed",
          ),
        )
      end
    end

    it "does not raise error if sibling contact integration does not exist" do
      contact_sint.destroy
      expect { upsert_webhook(svc, body: event_webhooks) }.to_not raise_error
    end

    it "sends expected events to contact integration for upsert" do
      insert_contact_row("contact_1")
      insert_contact_row("contact_2")

      contact_webhooks = [
        {"id" => "42636763-73f9-463e-af8b-3f720bb3d889",
         "type" => "contact.created",
         "list_id" => "list_id",
         "contact_id" => "contact_3",
         "occurred_at" => "2022-11-19T15:20:23+00:00",
         "contact_fields" => {
           "LastName" => "Example",
           "FirstName" => "Babs",
         },
         "contact_status" => "SUBSCRIBED",
         "contact_email_address" => "claire@example.com",
         "contact_tags" => ["vip"],},
        {
          "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
          "type" => "contact.deleted",
          "list_id" => "list_id",
          "contact_id" => "contact_1",
          "occurred_at" => "2022-11-20T15:20:23+00:00",
          "contact_fields" => {
            "LastName" => "Example",
            "FirstName" => "Abby",
          },
          "contact_status" => "UNSUBSCRIBED",
          "contact_email_address" => "claire@example.com",
          "contact_tags" => ["vip"],
        },
        {
          "id" => "42636763-73f9-463e-af8b-3f720bb3d889",
          "type" => "contact.updated",
          "list_id" => "list_id",
          "contact_id" => "contact_2",
          "occurred_at" => "2022-11-21T15:20:23+00:00",
          "contact_fields" => {
            "LastName" => "Example",
            "FirstName" => "Edna",
          },
          "contact_status" => "UNSUBSCRIBED",
          "contact_email_address" => "claire2@example.com",
          "contact_tags" => ["vip"],
        },
      ]

      upsert_webhook(svc, body: contact_webhooks)
      # check that the contact events have been recorded in the event table
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(3)
      end

      contact_svc.readonly_dataset do |contact_ds|
        expect(contact_ds.all).to contain_exactly(
          include(email_octopus_id: "contact_1", deleted_at: match_time("2022-11-20T15:20:23+00:00")),
          include(email_octopus_id: "contact_2", status: "UNSUBSCRIBED"),
          include(email_octopus_id: "contact_3", created_at: match_time("2022-11-19T15:20:23+00:00")),
        )
      end
    end

    it "noops if occurred_at is not present" do
      body = [{"id" => "cd7b763b-c4cb-4dd7-ad0e-f7ed650faa28",
               "type" => "contact.unsubscribed",
               "list_id" => "8f7c154e-0adc-11ee-acf6-b3c282ea3783",
               "contact_id" => "contact_1",
               "contact_fields" => {"LastName" => "Edson",
                                    "FirstName" => "Natalie",},
               "contact_status" => "UNSUBSCRIBED",
               "contact_email_address" => "Natalie@example.com",}]
      upsert_webhook(svc, body:)
      svc.readonly_dataset do |ds|
        expect(ds.all).to be_empty
      end
    end
  end

  describe "state machine calculation" do
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
        return stub_request(:get, "https://emailoctopus.com/api/1.6/lists?api_key=bfkey&limit=100").
            to_return(status: 200, body: success_body, headers: {"Content-Type" => "application/json"})
      end

      it "returns org database info" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start replicating your Email Octopus Events."),
        )
      end
    end
  end
end
