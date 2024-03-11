# frozen_string_literal: true

require "webhookdb/oauth"

RSpec.describe Webhookdb::Oauth::IncreaseProvider, :db do
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_member(customer).create }
  let(:provider) { Webhookdb::Oauth.provider("increase") }

  describe "authorization_url" do
    it "is valid" do
      expect(provider.authorization_url(state: "xyz")).to eq(
        "https://increase.com/oauth/authorization?client_id=increase_oauth_fake_client&state=xyz&scope=read_only",
      )
    end
  end

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
        with(body:, headers: {"Authorization" => "Bearer increase_api_key"}).
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

    it "builds the root and all child integrations and sets the group id on the service integration" do
      group_resp_body = {
        activation_status: "activated",
        ach_debit_status: "disabled",
        created_at: "2020-01-31T23:59:59Z",
        id: "group_1g4mhziu6kvrs3vz35um",
        type: "group",
      }
      group_req = stub_request(:get, "https://api.increase.com/groups/current").
        with(headers: {"Authorization" => "Bearer atok"}).
        to_return(json_response(group_resp_body))
      conns_resp_list = [
        {
          id: "conn_111",
          created_at: "2020-01-31T23:59:59Z",
          group_id: "group_111",
          status: "active",
          type: "oauth_connection",
        },
        {
          id: "connection_dauknoksyr4wilz4e6my",
          created_at: "2020-01-31T23:59:59Z",
          group_id: "group_1g4mhziu6kvrs3vz35um",
          status: "active",
          type: "oauth_connection",
        },
        {
          id: "conn_999",
          created_at: "2020-01-31T23:59:59Z",
          group_id: "group_222",
          status: "active",
          type: "oauth_connection",
        },
      ]
      conns_req = stub_request(:get, "https://api.increase.com/oauth_connections").
        with(headers: {"Authorization" => "Bearer increase_api_key"}).
        to_return(json_response({data: conns_resp_list}))

      root_sint = provider.build_marketplace_integrations(organization: org, tokens:, scope: nil)
      expect(root_sint).to have_attributes(organization: be === org, service_name: "increase_app_v1")
      expect(group_req).to have_been_made
      expect(conns_req).to have_been_made
      expect(org.refresh.service_integrations).to include(
        have_attributes(
          service_name: "increase_app_v1",
          api_url: "group_1g4mhziu6kvrs3vz35um",
          backfill_key: "atok",
          webhookdb_api_key: "connection_dauknoksyr4wilz4e6my",
        ),
        have_attributes(service_name: "increase_account_v1"),
        have_attributes(service_name: "increase_wire_transfer_v1"),
      )
    end

    it "errors if there is no oauth conn for the group" do
      group_resp_body = {
        activation_status: "activated",
        ach_debit_status: "disabled",
        created_at: "2020-01-31T23:59:59Z",
        id: "group_1g4mhziu6kvrs3vz35um",
        type: "group",
      }
      group_req = stub_request(:get, "https://api.increase.com/groups/current").
        to_return(json_response(group_resp_body))
      conns_req = stub_request(:get, "https://api.increase.com/oauth_connections").
        to_return(json_response({data: []}))

      expect do
        provider.build_marketplace_integrations(organization: org, tokens:, scope: nil)
      end.to raise_error(Webhookdb::InvariantViolation, /no OAuth/)
      expect(group_req).to have_been_made
      expect(conns_req).to have_been_made
    end
  end

  describe "disconnect_oauth" do
    let!(:sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "increase_app_v1", api_url: "group_xyz", webhookdb_api_key: "conn_abc",
      )
    end

    it "deletes the replicator tree for the integration with the connection id" do
      described_class.disconnect_oauth("conn_abc")
      expect(sint).to be_destroyed
    end

    it "noops if there is no service integration for connection" do
      described_class.disconnect_oauth("conn_xyz")
      expect(sint).to_not be_destroyed
    end
  end
end
