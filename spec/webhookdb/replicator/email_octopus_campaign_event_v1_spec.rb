# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::EmailOctopusCampaignEventV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:campaign_sint) do
    Webhookdb::Fixtures.service_integration.create(service_name: "email_octopus_campaign_v1", organization: org)
  end
  let(:sint) do
    Webhookdb::Fixtures.service_integration.depending_on(campaign_sint).create(
      service_name: "email_octopus_campaign_event_v1",
      organization: org,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  it_behaves_like "a replicator", "email_octopus_campaign_event_v1" do
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

  it_behaves_like "a replicator dependent on another", "email_octopus_campaign_event_v1",
                  "email_octopus_campaign_v1" do
    let(:no_dependencies_message) { "This integration requires Email Octopus Campaigns to sync" }
  end

  it_behaves_like "a replicator that can backfill", "email_octopus_campaign_event_v1" do
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
            "next": "/api/1.6/campaigns/1/reports/complained?api_key=campaign_bf_key&limit=100&page=2"
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
      return lambda do |campaign_svc|
        campaign_svc.service_integration.update(backfill_key: "campaign_bf_key")
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
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/clicked?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=campaign_bf_key&limit=100").
            to_return(
              status: 200,
              body: campaign_1_complained_response_page1,
              headers: {"Content-Type" => "application/json"},
            ),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=campaign_bf_key&limit=100&page=2").
            to_return(
              status: 200,
              body: campaign_1_complained_response_page2,
              headers: {"Content-Type" => "application/json"},
            ),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/opened?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/sent?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/unsubscribed?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/bounced?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/clicked?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/complained?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/opened?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/sent?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/unsubscribed?api_key=campaign_bf_key&limit=100").
            to_return(
              status: 200,
              body: campaign_2_unsubscribed_response,
              headers: {"Content-Type" => "application/json"},
            ),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=campaign_bf_key&limit=100").
          to_return(status: 403)
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/bounced?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/clicked?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/complained?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/opened?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/sent?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/1/reports/unsubscribed?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/bounced?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/clicked?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/complained?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/opened?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/sent?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns/2/reports/unsubscribed?api_key=campaign_bf_key&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  describe "getting credentials from dependency" do
    it "raises err if credentials are not set on campaign replicator" do
      err_msg = "This integration requires that the Email Octopus Campaign integration has a valid API Key"
      sint.depends_on.update(backfill_key: "")
      expect do
        backfill(sint)
      end.to raise_error(Webhookdb::Replicator::CredentialsMissing).with_message(err_msg)
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
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start replicating your Email Octopus Campaign Events."),
        )
      end
    end
  end
end
