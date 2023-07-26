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

  it_behaves_like "a replicator dependent on another", "email_octopus_campaign_v1",
                  "email_octopus_list_v1" do
    let(:no_dependencies_message) { "This integration requires Email Octopus Lists to sync" }
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

  describe "state machine calculation" do
    let(:list_sint) { Webhookdb::Fixtures.service_integration.create(service_name: "email_octopus_list_v1") }
    let(:sint) do
      Webhookdb::Fixtures.service_integration.depending_on(list_sint).create(service_name: "email_octopus_campaign_v1")
    end
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

      it "returns org database info" do
        sint.backfill_key = "bfkey"
        sm = sint.replicator.calculate_backfill_state_machine
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
