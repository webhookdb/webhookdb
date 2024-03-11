# frozen_string_literal: true

require "webhookdb/oauth"

RSpec.describe Webhookdb::Oauth::FrontProvider, :db do
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_member(customer).create }
  let(:front_instance_api_url) { "webhookdb_test.api.frontapp.com" }
  let(:provider) { Webhookdb::Oauth.provider("front") }

  describe "authorization_url" do
    it "is valid" do
      # It's possible the redirect URI should be coded, but we didn't do it,
      # and it seems to work fine, so leave it for now.
      expect(provider.authorization_url(state: "xyz")).to eq(
        "https://app.frontapp.com/oauth/authorize?response_type=code&" \
        "redirect_uri=http://localhost:18001/v1/install/front/callback&state=xyz&client_id=front_client_id",
      )
    end
  end

  describe "exchange_authorization_code" do
    def stub_auth_token_request
      body = {
        "code" => "front_test_auth",
        "redirect_uri" => "http://localhost:18001/v1/install/front/callback",
        "grant_type" => "authorization_code",
      }.to_json
      return stub_request(:post, "https://app.frontapp.com/oauth/token").with(body:).
          to_return(json_response(load_fixture_data("front/auth_token_response")))
    end

    it "calls the provider" do
      req = stub_auth_token_request
      tokens = provider.exchange_authorization_code(code: "front_test_auth")
      expect(tokens).to have_attributes(access_token: "AYjcyMzY3ZDhiNmJkNTY", refresh_token: "RjY2NjM5NzA2OWJjuE7c")
      expect(req).to have_been_made
    end
  end

  describe "build_marketplace_integrations" do
    let(:tokens) do
      Webhookdb::Oauth::Tokens.new(
        access_token: "AYjcyMzY3ZDhiNmJkNTY", refresh_token: "RjY2NjM5NzA2OWJjuE7c",
      )
    end

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_token_info_request
      return stub_request(:get, "https://api2.frontapp.com/me").
          to_return(json_response(load_fixture_data("front/token_info_response")))
    end

    it "builds integrations" do
      req = stub_token_info_request
      root_sint = provider.build_marketplace_integrations(organization: org, tokens:, scope: nil)
      expect(req).to have_been_made
      expect(root_sint).to have_attributes(organization: be === org, service_name: "front_marketplace_root_v1")
      expect(org.refresh.service_integrations).to contain_exactly(
        have_attributes(
          service_name: "front_marketplace_root_v1",
          api_url: front_instance_api_url,
          # We can't match on an encrypted field, but the backfill_key of the root should be the
          # Front refresh token. We can just test that the field isn't nil
          backfill_key: not_be_nil,
        ),
        have_attributes(service_name: "front_message_v1"),
        have_attributes(service_name: "front_conversation_v1"),
      )
    end
  end

  describe "SignalwireProvider" do
    describe "build_marketplace_integrations" do
      it "are not implemented" do
        p = Webhookdb::Oauth.provider("front_signalwire")
        expect do
          p.build_marketplace_integrations(organization: nil, scope: nil, tokens: nil)
        end.to raise_error(NotImplementedError, /Front channels have a different setup/)
      end
    end
  end
end
