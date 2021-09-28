# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  describe "convertkit subscriber v1" do
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
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [{}] }
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
      let(:expected_backfill_call_count) { 2 }
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      before(:each) do
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1").
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=2").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
      end
    end

    describe "webhook creation" do
      let(:sint) do
        Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_subscriber_v1",
                                                       backfill_secret: "bfsek",)
      end
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "creates activate webhook" do
        req = stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
          to_return(
            status: 200,
          )

        svc.create_activate_webhook
        expect(req).to have_been_made
      end

      it "creates unsubscribe webhook" do
        req = stub_request(:post, "https://api.convertkit.com/v3/automations/hooks").
          to_return(
            status: 200,
          )

        svc.create_unsubscribe_webhook
        expect(req).to have_been_made
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
        it "returns org database info" do
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! We've created your ConvertKit Subscriber Service Integration.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "it asks for backfill secret" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your API secret here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/" \
                                                    "transition/backfill_secret")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("In order to backfill ConvertKit Subscribers, we need your API secret.")
        end
        it "returns backfill in progress message" do
          sint.backfill_secret = "api_s3cr3t"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your ConvertKit Subscriber information.",
          )
        end
      end
    end
  end
end
