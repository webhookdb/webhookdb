# frozen_string_literal: true

require "webhookdb/oauth"

RSpec.describe Webhookdb::Oauth::IncreaseProvider, :db do
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_member(customer).create }
  let(:provider) { Webhookdb::Oauth.provider("increase") }

  describe "exchange_authorization_code" do
    def stub_auth_token_request
      body = {
        client_id: "increase_oauth_fake_client",
        client_secret: "increase_oauth_fake_secret",
        code: "increase_auth_code",
        grant_type: "authorization_code",
      }.to_json
      resp = {
        access_token: "RI5vGMbBv8UPqUhk0YHZ45hG2XpEDzDp",
        token_type: "bearer",
      }
      stub_request(:post, "https://api.increase.com/oauth/tokens").
        with(body:).
        to_return(json_response(resp))
    end

    it "calls the provider" do
      req = stub_auth_token_request
      tokens = provider.exchange_authorization_code(code: "increase_auth_code")
      expect(tokens).to have_attributes(access_token: "RI5vGMbBv8UPqUhk0YHZ45hG2XpEDzDp", refresh_token: nil)
      expect(req).to have_been_made
    end
  end

  describe "build_marketplace_integrations" do
    let(:tokens) do
      Webhookdb::Oauth::Tokens.new(access_token: "atok")
    end

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "builds the root and all child integrations" do
      root_sint = provider.build_marketplace_integrations(organization: org, tokens:, scope: nil)
      expect(root_sint).to have_attributes(organization: be === org, service_name: "increase_app_v1")
      expect(org.refresh.service_integrations).to include(
        have_attributes(
          service_name: "increase_app_v1",
          backfill_key: not_be_nil,
        ),
        have_attributes(service_name: "increase_account_v1"),
        have_attributes(service_name: "increase_wire_transfer_v1"),
      )
    end
  end
end
