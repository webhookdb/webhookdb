# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestAuthV1, :db do
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(service_name: "theranest_auth_v1", backfill_key: "username",
                                                   backfill_secret: "password",)
  end
  let(:svc) { Webhookdb::Services.service_instance(sint) }

  it "can create its table in its org db" do
    sint.organization.prepare_database_connections
    svc.create_table
    svc.readonly_dataset do |ds|
      expect(ds.db).to be_table_exists(svc.table_sym)
    end
    expect(sint.db).to_not be_table_exists(svc.table_sym)
    sint.organization.remove_related_database
  end

  describe "state machine calculation" do
    # `calculate_backfill_state_machine` just calls `calculate_create_state_machine`,
    # so it doesn't need to be tested
    describe "calculate_create_state_machine" do
      before(:each) do
        sint.update(backfill_key: "", backfill_secret: "")
      end

      it "asks for backfill key (username)" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your username here:",
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to create and maintain auth credentials"),
        )
      end

      it "asks for backfill secret (password)" do
        sint.backfill_key = "username"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your password here:",
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: "",
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.backfill_key = "username"
        sint.backfill_secret = "password"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("WebhookDB will create a new auth cookie"),
        )
      end
    end
  end

  describe "get_auth_cookie" do
    def auth_stub_request
      return stub_request(:post, "https://fake-url.com/home/signin").to_return(
        status: 200,
        headers: {"Set-Cookie" => "new_cookie"},
      )
    end

    it "returns existing cookie if it was generated less than fifteen minutes ago" do
      sint.webhook_secret = "the_cookie"
      sint.last_backfilled_at = DateTime.now
      expect(svc.get_auth_cookie).to eq("the_cookie")
    end

    it "makes a request to Theranest API" do
      response = auth_stub_request
      svc.get_auth_cookie
      expect(response).to have_been_made
    end

    it "updates `webhook_secret` and `last_backfilled_at` values on the integration" do
      auth_stub_request
      svc.get_auth_cookie
      expect(sint.webhook_secret).to eq("new_cookie")
      expect(sint.last_backfilled_at).to be_within(30.seconds).of(DateTime.now)
    end
  end
end
