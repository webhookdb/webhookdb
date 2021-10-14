# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::ConvertkitSubscriberV1, :db do
  it_behaves_like "a service implementation", "convertkit_subscriber_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": 1,
          "first_name": "Anne",
          "email_address": "acarson@example.com",
          "state": "active",
          "created_at": "2016-02-28T08:07:00Z",
          "fields": {
            "last_name": "Carson"
          }
        }
      J
    end
    let(:expected_data) { body }
  end

  it_behaves_like "a service implementation that prevents overwriting new data with old",
                  "convertkit_subscriber_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": 1,
          "first_name": "Anne",
          "email_address": "acarson@example.com",
          "state": "active",
          "created_at": "2016-02-28T08:07:00Z",
          "fields": {
            "last_name": "Carson"
          }
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": 1,
          "first_name": "Anne",
          "email_address": "acarson@example.com",
          "state": "active",
          "created_at": "2016-09-28T08:07:00Z",
          "fields": {
            "last_name": "Carson"
          }
        }
      J
    end
  end

  it_behaves_like "a service implementation that can backfill", "convertkit_subscriber_v1" do
    let(:page1_response) do
      <<~R
        {
          "total_subscribers": 3,
          "page": 1,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 1,
              "first_name": "Emily",
              "email_address": "emilydickinson@example.com",
              "state": "active",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Dickinson"
              }
            },
            {
              "id": 2,
              "first_name": "Gertrude",
              "email_address": "tenderbuttons@example.com",
              "state": "active",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Stein"
              }
            }
          ]
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "total_subscribers": 3,
          "page": 2,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 3,
              "first_name": "Eileen",
              "email_address": "eileenmyles@example.com",
              "state": "active",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Myles"
              }
            }
          ]
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "total_subscribers": 2,
          "page": 1,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 4,
              "first_name": "Ezra",
              "email_address": "ezra@example.com",
              "state": "cancelled",
              "cancelled_at": "2016-03-28T08:07:00Z",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Pound"
              }
            }
          ]
        }
      R
    end
    let(:page4_response) do
      <<~R
        {
          "total_subscribers": 2,
          "page": 2,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 5,
              "first_name": "Dean",
              "email_address": "dean@example.com",
              "state": "cancelled",
              "cancelled_at": "2016-03-28T08:07:00Z",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Young"
              }
            }
          ]
        }
      R
    end
    let(:expected_items_count) { 5 }

    def stub_service_requests
      return [
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=2&sort_order=desc").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc&sort_field=cancelled_at").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=2&sort_order=desc&sort_field=cancelled_at").
            to_return(status: 200, body: page4_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc").
          to_return(status: 503, body: "error")
    end
  end

  it_behaves_like "a service implementation that can backfill incrementally", "convertkit_subscriber_v1" do
    let(:page1_response) do
      <<~R
        {
          "total_subscribers": 3,
          "page": 1,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 1,
              "first_name": "Emily",
              "email_address": "emilydickinson@example.com",
              "state": "active",
              "created_at": "2016-02-28T08:07:00Z",
              "fields": {
                "last_name": "Dickinson"
              }
            },
            {
              "id": 2,
              "first_name": "Gertrude",
              "email_address": "tenderbuttons@example.com",
              "state": "active",
              "created_at": "2016-01-27T08:07:00Z",
              "fields": {
                "last_name": "Stein"
              }
            }
          ]
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "total_subscribers": 3,
          "page": 2,
          "total_pages": 2,
          "subscribers": [
            {
              "id": 3,
              "first_name": "Eileen",
              "email_address": "eileenmyles@example.com",
              "state": "active",
              "created_at": "2016-01-01T08:07:00Z",
              "fields": {
                "last_name": "Myles"
              }
            }
          ]
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "total_subscribers": 0,
          "page": 1,
          "total_pages": 1,
          "subscribers": [
          ]
        }
      R
    end
    let(:expected_new_items_count) { 2 }
    let(:expected_old_items_count) { 1 }
    let(:last_backfilled) { "2016-02-01T21:45:16.000Z" }

    def stub_service_requests_new_records
      return [
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc&sort_field=cancelled_at").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_requests_old_records
      return [
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=2&sort_order=desc").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end
  end

  describe "webhook creation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1")
    end
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "creates activate and unsubscribe webhooks when backfill_secret is set" do
      req1 = stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
        with(body: include("subscriber.subscriber_activate").and(include("mysecret"))).
        to_return(status: 200)
      req2 = stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
        with(body: include("subscriber.subscriber_unsubscribe").and(include("mysecret"))).
        to_return(status: 200)

      svc.process_state_change("backfill_secret", "mysecret")
      expect(req1).to have_been_made
      expect(req2).to have_been_made
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 202 no matter what" do
      req = fake_request
      status, _headers, _body = svc.webhook_response(req)
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "calculate_create_state_machine" do
      it "returns the expected step" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: false,
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("ConvertKit supports Subscriber webhooks."),
        )
      end
    end
    describe "calculate_backfill_state_machine" do
      it "it asks for backfill secret" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret",
          complete: false,
          output: match("we need your API secret"),
        )
      end
      it "returns backfill in progress message" do
        sint.backfill_secret = "api_s3cr3t"
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: false,
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("We are going to start backfilling"),
        )
      end
    end
  end
end
