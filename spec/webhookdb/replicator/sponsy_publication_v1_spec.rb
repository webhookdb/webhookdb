# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::SponsyPublicationV1, :db do
  it_behaves_like "a replicator", "sponsy_publication_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "a283ce57-d5a9-4a33-87b9-817226631c3e",
          "createdAt": "2022-04-26T18:15:48.737Z",
          "updatedAt": "2022-08-09T19:18:31.215Z",
          "name": "SITC Podcast",
          "slug": "sitc-podcast",
          "type": "PODCAST",
          "days": [
            3,
            1
          ]
        }
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "sponsy_publication_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "a283ce57-d5a9-4a33-87b9-817226631c3e",
          "createdAt": "2022-04-26T18:15:48.737Z",
          "updatedAt": "2022-08-09T19:18:31.215Z",
          "name": "SITC Podcast1",
          "slug": "sitc-podcast",
          "type": "PODCAST",
          "days": [
            3,
            1
          ]
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "a283ce57-d5a9-4a33-87b9-817226631c3e",
          "createdAt": "2022-04-26T18:15:48.737Z",
          "updatedAt": "2022-08-10T19:18:31.215Z",
          "name": "SITC Podcast2",
          "slug": "sitc-podcast",
          "type": "PODCAST",
          "days": [
            3,
            1
          ]
        }
      J
    end
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "sponsy_publication_v1", backfill_secret: "right")
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "sponsy_publication_v1", backfill_secret: "wrong")
    end

    def stub_service_request
      return stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
          with(headers: {"X-Api-Key" => "right"}).
          to_return(status: 200, body: '{"data":[],"cursor":{}}', headers: {"Content-Type" => "application/json"})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
          with(headers: {"X-Api-Key" => "wrong"}).
          to_return(status: 401, body: "{}", headers: {"Content-Type" => "application/json"})
    end
  end

  it_behaves_like "a replicator that can backfill", "sponsy_publication_v1" do
    let(:page1_response) do
      <<~R
        {
          "data": [
            {
              "id": "a283ce57-d5a9-4a33-87b9-817226631c3e",
              "createdAt": "2022-04-26T18:15:48.737Z",
              "updatedAt": "2022-08-09T19:18:31.215Z",
              "name": "SITC Podcast",
              "slug": "sitc-podcast",
              "type": "PODCAST",
              "days": [
                3,
                1
              ]
            },
            {
              "id": "8c930673-8c26-40e7-8868-83c6ee731931",
              "createdAt": "2022-05-23T17:19:31.668Z",
              "updatedAt": "2022-05-23T17:19:31.668Z",
              "name": "LWIA Podcast",
              "slug": "lwia-podcast",
              "type": "PODCAST",
              "days": [
                0,
                2,
                3
              ]
            }
          ],
          "cursor": {
            "afterCursor": "dXBkYXRlZEF0OjE2NTMzMjYzNzE2Njg=",
            "beforeCursor": null
          }
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "data": [
            {
              "id": "ffde5f3e-fc2e-4abd-b0ad-57e11e98b2a1",
              "createdAt": "2022-02-16T22:42:28.707Z",
              "updatedAt": "2022-05-16T18:08:24.823Z",
              "name": "LWIA Youtube",
              "slug": "lwia-youtube",
              "type": "YOUTUBE",
              "days": [
                3
              ]
            }
          ],
          "cursor": {
            "afterCursor": "dXBkYXRlZEF0OjE2NTI3MjQ0ODczMDQ=",
            "beforeCursor": "dXBkYXRlZEF0OjE2NTI3MjQ1MDQ4MjM="
          }
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "data": [],
          "cursor": {
            "afterCursor": null,
            "beforeCursor": "dXBkYXRlZEF0OjE2NDY3NzcyNTYyMjI="
          }
        }
      R
    end
    let(:expected_items_count) { 3 }

    def stub_service_requests
      return [
        stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            with(headers: {"X-Api-Key" => /.*/}).
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=dXBkYXRlZEF0OjE2NTMzMjYzNzE2Njg=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=dXBkYXRlZEF0OjE2NTI3MjQ0ODczMDQ=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
          to_return(status: 503, body: "woah")
    end
  end

  it_behaves_like "a replicator that can backfill incrementally", "sponsy_publication_v1" do
    let(:last_backfilled) { "2022-09-01T18:00:00Z" }
    let(:expected_new_items_count) { 2 }
    let(:expected_old_items_count) { 1 }

    def make_body(dates, cursor)
      data = dates.map do |date|
        {
          id: "item-#{date}",
          createdAt: "#{date}T18:15:48.737Z",
          updatedAt: "#{date}T18:15:48.737Z",
          name: "SITC Podcast",
          slug: "sitc-podcast",
          type: "PODCAST",
          days: [],
        }
      end
      return {data:, cursor: {afterCursor: cursor}}.to_json
    end

    def stub_service_requests(partial:)
      url = "https://api.getsponsy.com/v1/publications"
      headers = {"Content-Type" => "application/json"}
      if partial
        return [
          stub_request(:get, "#{url}?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
              to_return(status: 200, body: make_body(["2022-09-02"], "cursor1"), headers:),
          stub_request(:get, "#{url}?afterCursor=cursor1&limit=100&orderBy=updatedAt&orderDirection=DESC").
              to_return(status: 200, body: make_body(["2022-09-01"], nil), headers:),
        ]
      end
      return [
        stub_request(:get, "#{url}?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: make_body(["2022-09-02"], "cursor1"), headers:),
        stub_request(:get, "#{url}?afterCursor=cursor1&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: make_body(["2022-09-01"], "cursor2"), headers:),
        stub_request(:get, "#{url}?afterCursor=cursor2&limit=100&orderBy=updatedAt&orderDirection=DESC").
            to_return(status: 200, body: make_body(["2022-08-31"], nil), headers:),
      ]
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "sponsy_publication_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns ok" do
      req = Rack::Request.new({})
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "sponsy_publication_v1", backfill_secret: "")
    end
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_create_state_machine" do
      it "returns a backfill state machine" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("Head over to your Sponsy dashboard"),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      def stub_service_request
        return stub_request(:get, "https://api.getsponsy.com/v1/publications?afterCursor=&limit=100&orderBy=updatedAt&orderDirection=DESC").
            with(headers: {"X-Api-Key" => "bfsek"}).
            to_return(status: 200, body: '{"data":[],"cursor":{}}', headers: {"Content-Type" => "application/json"})
      end

      it "asks for backfill secret" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your API key here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: /Head over to your Sponsy dashboard/,
        )
      end

      it "returns org database info" do
        sint.backfill_secret = "bfsek"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Sponsy Publications"),
        )
      end
    end
  end
end
