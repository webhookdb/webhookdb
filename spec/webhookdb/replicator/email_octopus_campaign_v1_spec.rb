# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::EmailOctopusCampaignV1, :db do
  it_behaves_like "a replicator", "email_octopus_campaign_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "00000000-0000-0000-0000-000000000000",
          "status": "SENT",
          "name": "Foo",
          "subject": "Bar",
          "to": [
            "00000000-0000-0000-0000-000000000001",
            "00000000-0000-0000-0000-000000000002"
          ],
          "from": {
            "name": "John Doe",
            "email_address": "john.doe@gmail.com"
          },
          "content": {
            "html": "<html>Foo Bar<html>",
            "plain_text": "Foo Bar"
          },
          "created_at": "2023-07-02T15:40:12+00:00",
          "sent_at": "2023-07-03T15:40:12+00:00"
        }
      J
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "email_octopus_campaign_v1",
        backfill_key: "bfkey",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "email_octopus_campaign_v1",
        backfill_key: "bfkey_wrong",
      )
    end

    let(:success_body) do
      <<~R
        {
          "data": [],
          "paging": {}
        }
      R
    end

    def stub_service_request
      return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100").
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey_wrong&limit=100").
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a replicator that can backfill", "email_octopus_campaign_v1" do
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
              "status": "SENT",
              "name": "Foo",
              "subject": "Bar",
              "to": [
                  "00000000-0000-0000-0000-000000000001",
                  "00000000-0000-0000-0000-000000000002"
              ],
              "from": {
                  "name": "John Doe",
                  "email_address": "john.doe@gmail.com"
              },
              "content": {
                  "html": "<html>Foo Bar<html>",
                  "plain_text": "Foo Bar"
              },
              "created_at": "2023-07-02T15:40:12+00:00",
              "sent_at": "2023-07-03T15:40:12+00:00"
            }
          ],
          "paging": {
            "next": "/api/1.6/campaigns?api_key=bfkey&limit=100&page=2",
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
              "id": "00000000-0000-0000-0000-000000000003",
              "status": "SENT",
              "name": "Bar",
              "subject": "Foo",
              "to": [
                "00000000-0000-0000-0000-000000000004",
                "00000000-0000-0000-0000-000000000005"
              ],
              "from": {
                "name": "Jane Doe",
                "email_address": "jane.doe@gmail.com"
              },
              "content": {
                "html": "<html>Bar Foo<html>",
                "plain_text": "Bar Foo"
              },
              "created_at": "2023-07-04T15:40:12+00:00",
              "sent_at": "2023-07-05T15:40:12+00:00"
            }
          ],
          "paging": {
            "next": null,
            "previous": "/api/1.6/campaigns?api_key=bfkey&limit=100"
          }
        }
      R
    end
    let(:expected_items_count) { 2 }

    def stub_service_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100&page=2").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100").
          to_return(status: 403)
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100").
            to_return(status: 200, body: empty_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  it_behaves_like "a replicator with dependents", "email_octopus_campaign_v1", "email_octopus_campaign_event_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "0",
          "status": "SENT",
          "name": "Foo",
          "subject": "Bar",
          "to": [
            "00000000-0000-0000-0000-000000000001",
            "00000000-0000-0000-0000-000000000002"
          ],
          "from": {
            "name": "John Doe",
            "email_address": "john.doe@gmail.com"
          },
          "content": {
            "html": "<html>Foo Bar<html>",
            "plain_text": "Foo Bar"
          },
          "created_at": "2023-07-02T15:40:12+00:00",
          "sent_at": "2023-07-03T15:40:12+00:00"
        }
      J
    end
    let(:can_track_row_changes) { true }
    let(:expected_insert) do
      {
        name: "Foo",
        created_at: match_time("2023-07-02T15:40:12+00:00"),
        sent_at: match_time("2023-07-03T15:40:12+00:00"),
        row_updated_at: match_time(:now),
        data: body.to_json,
        email_octopus_id: "0",
        from_email_address: "john.doe@gmail.com",
        from_name: "John Doe",
        status: "SENT",
        subject: "Bar",
      }
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "email_octopus_campaign_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

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
        return stub_request(:get, "https://emailoctopus.com/api/1.6/campaigns?api_key=bfkey&limit=100").
            to_return(status: 200, body: success_body, headers: {"Content-Type" => "application/json"})
      end
      it "asks for backfill key" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API Key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to replicate Email Octopus Campaigns into WebhookDB, we need an API Key."),
        )
      end

      it "confirms reciept of backfill key, returns org database info" do
        sint.backfill_key = "bfkey"
        res = stub_service_request
        sm = sint.replicator.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start replicating your Email Octopus Campaigns."),
        )
      end
    end
  end
end
