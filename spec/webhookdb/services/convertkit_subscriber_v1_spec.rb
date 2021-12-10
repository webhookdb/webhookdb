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

  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_subscriber_v1",
        backfill_secret: "bfsek",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "convertkit_subscriber_v1",
        backfill_secret: "bfsek_wrong",
      )
    end

    let(:success_body) do
      <<~R
                {
                  "total_subscribers": 3,
                  "page": 1,
                  "total_pages": 2,
                  "subscribers": [#{'    '}
        #{'        '}
                  ]
                }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc").
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek_wrong&page=1&sort_order=desc").
          to_return(status: 401, body: "", headers: {})
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

  describe "cancelated_at calculations" do
    let(:body) do
      {"id" => 1, "created_at" => "2016-02-28T08:07:00Z"}
    end
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "uses nil if the subscriber state is active" do
      body["state"] = "active"
      svc.upsert_webhook(body: body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(convertkit_id: 1, canceled_at: nil, state: "active")
      end
    end
    it "uses now if the subscriber state is inactive and canceled_at is nil" do
      body["state"] = "inactive"
      svc.upsert_webhook(body: body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(convertkit_id: 1, canceled_at: match_time(Time.now).within(5), state: "inactive")
      end
    end
    it "replaces canceled_at with nil if state is active (such as due to a resubscribe)" do
      body["state"] = "inactive"
      svc.upsert_webhook(body: body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(canceled_at: be_present)
      end

      body["state"] = "active"
      svc.upsert_webhook(body: body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(convertkit_id: 1, canceled_at: nil, state: "active")
      end
    end
    it "does not change canceled_at if the subscriber state is inactive and canceled_at is set" do
      t = 3.months.ago
      Timecop.freeze(t) do
        body["state"] = "inactive"
        svc.upsert_webhook(body: body)
        svc.readonly_dataset do |ds|
          expect(ds.all).to have_length(1)
          expect(ds.first).to include(convertkit_id: 1, canceled_at: match_time(t), state: "inactive")
        end
      end

      svc.upsert_webhook(body: body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first).to include(convertkit_id: 1, canceled_at: match_time(t), state: "inactive")
      end
    end
  end

  describe "webhook creation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1")
    end
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    let(:verify_creds_request) do
      stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=mysecret&page=1&sort_order=desc").
        to_return(status: 200, body: "", headers: {})
    end

    it "creates activate and unsubscribe webhooks when backfill_secret is set" do
      creds_response = verify_creds_request
      webhook_response = stub_request(:get, "https://api.convertkit.com/v3/automations/hooks?api_secret=mysecret").
        to_return(status: 200, body: "", headers: {"Content-Type" => "application/json"})
      create_responses = [stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
        with(body: include("subscriber.subscriber_activate").and(include("mysecret"))).
        to_return(status: 200),
                          stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
                            with(body: include("subscriber.subscriber_unsubscribe").and(include("mysecret"))).
                            to_return(status: 200),]

      svc.process_state_change("backfill_secret", "mysecret")
      expect(creds_response).to have_been_made
      expect(webhook_response).to have_been_made
      expect(create_responses).to all(have_been_made)
    end

    it "does not create activate and unsubscribe webhooks if they already exist" do
      creds_response = verify_creds_request
      existing_webhooks_body = <<~R
        [
          {
            "rule": {
              "id": 1,
              "account_id": 123456,
              "status": "enabled",
              "event": {
                "name": "subscriber_activate",
                "initiator_value": null
              },
              "target_url": "https://api.webhookdb.com/v1/service_integrations/opaque_id"
            }
          },
          {
            "rule": {
              "id": 2,
              "account_id": 123456,
              "status": "enabled",
              "event": {
                "name": "subscriber_unsubscribe",
                "initiator_value": null
              },
              "target_url": "https://api.webhookdb.com/v1/service_integrations/opaque_id"
            }
          }
        ]
      R
      webhook_response = stub_request(:get, "https://api.convertkit.com/v3/automations/hooks?api_secret=mysecret").
        to_return(status: 200, body: existing_webhooks_body, headers: {"Content-Type" => "application/json"})

      svc.process_state_change("backfill_secret", "mysecret")
      expect(creds_response).to have_been_made
      expect(webhook_response).to have_been_made
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
      def stub_service_request
        return stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1&sort_order=desc").
            to_return(status: 200, body: "", headers: {})
      end
      it "it asks for backfill secret" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret",
          complete: false,
          output: match("which requires your API Secret"),
        )
      end
      it "returns backfill in progress message" do
        sint.backfill_secret = "bfsek"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: false,
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("We'll start backfilling your ConvertKit Subscribers"),
        )
      end
    end
  end
end
