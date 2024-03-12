# frozen_string_literal: true

require "webhookdb/oauth"

RSpec.describe Webhookdb::Oauth::IntercomProvider, :db do
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_member(customer).create }
  let(:provider) { Webhookdb::Oauth.provider("intercom") }

  describe "authorization_url" do
    it "is valid" do
      expect(provider.authorization_url(state: "xyz")).to eq(
        "https://app.intercom.com/oauth?client_id=whdb_intercom_client_id&state=xyz",
      )
    end
  end

  describe "exchange_authorization_code" do
    def stub_auth_token_request
      return stub_request(:post, "https://api.intercom.io/auth/eagle/token").
          to_return(json_response(load_fixture_data("intercom/token_response")))
    end

    it "calls the provider" do
      req = stub_auth_token_request
      tokens = provider.exchange_authorization_code(code: "intercom_test_auth")
      expect(tokens).to have_attributes(access_token: "intercom_auth_token", refresh_token: nil)
      expect(req).to have_been_made
    end
  end

  describe "build_marketplace_integrations" do
    let(:tokens) { Webhookdb::Oauth::Tokens.new(access_token: "intercom_auth_token", refresh_token: nil) }

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "builds integrations" do
      req = stub_request(:get, "https://api.intercom.io/me").
        to_return(json_response(load_fixture_data("intercom/get_user")))

      root_sint = provider.build_marketplace_integrations(organization: org, tokens:)
      expect(root_sint).to have_attributes(organization: be === org, service_name: "intercom_marketplace_root_v1")
      expect(req).to have_been_made
      expect(org.refresh.service_integrations).to contain_exactly(
        have_attributes(
          service_name: "intercom_marketplace_root_v1",
          api_url: "lithic_tech_intercom_abc",
          backfill_key: not_be_nil,
        ),
        have_attributes(service_name: "intercom_conversation_v1"),
        have_attributes(service_name: "intercom_contact_v1"),
      )

      expect(Webhookdb::BackfillJob.all).to contain_exactly(
        have_attributes(
          service_integration: have_attributes(service_name: "intercom_contact_v1"),
          incremental: true,
        ),
        have_attributes(
          service_integration: have_attributes(service_name: "intercom_conversation_v1"),
          incremental: true,
        ),
      )
    end
  end
end
