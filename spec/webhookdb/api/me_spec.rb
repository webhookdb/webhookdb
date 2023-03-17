# frozen_string_literal: true

require "webhookdb/api/me"

RSpec.describe Webhookdb::API::Me, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:customer) { Webhookdb::Fixtures.customer.create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/me" do
    it "returns the authed customer" do
      get "/v1/me"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(email: customer.email)
    end

    it "can render a full customer" do
      customer.update(email: "a@b.co")
      om_fac = Webhookdb::Fixtures.organization_membership(customer:)
      om_fac.org(name: "Hi").verified.default.create
      om_fac.org(name: "Bye").verified.admin.create
      om_fac.org(name: "Bar").invite.code("code1").create
      om_fac.org(name: "Foo").invite.code("code2").create

      get "/v1/me"

      expect(last_response).to have_status(200)
      b = last_response_json_body
      lines = b[:display_headers].map { |(k, f)| [f, b[k.to_sym]] }
      expect(lines).to contain_exactly(
        ["Default Org", "Hi (hi)"],
        ["Email", "a@b.co"],
        ["Memberships", "Hi (hi): member\nBye (bye): admin"],
        ["Invitations", "Bar (bar): code1\nFoo (foo): code2"],
      )
    end

    it "errors if the customer is soft deleted" do
      customer.soft_delete

      get "/v1/me"

      expect(last_response).to have_status(401)
    end

    it "401s if not logged in" do
      logout

      get "/v1/me"

      expect(last_response).to have_status(401)
    end
  end

  describe "GET /v1/me/organization_memberships" do
    let!(:org) { Webhookdb::Fixtures.organization.create }
    let!(:membership) { Webhookdb::Fixtures.organization_membership(customer:, organization: org).verified.create }
    let!(:invited_org) { Webhookdb::Fixtures.organization.create }
    let!(:invited_membership) do
      Webhookdb::Fixtures.organization_membership(
        customer:,
        organization: invited_org,
      ).invite.create(invitation_code: "join-abc123")
    end

    it "returns correct 'block' information for a customer with both verified and unverified memberships" do
      get "/v1/me/organization_memberships", active_org_identifier: org.key

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          blocks: contain_exactly(
            {
              type: "line",
              value: "You are a member of the following organizations:",
            },
            {type: "line", value: ""},
            {
              type: "table",
              value: {
                headers: [
                  "Name",
                  "Key",
                  "Role",
                  "Status",
                ],
                rows: [
                  [
                    org.name,
                    org.key,
                    membership.status,
                    "active",
                  ],
                ],
              },
            },
            {type: "line", value: ""},
            {
              type: "line",
              value: "You have been invited to the following organizations:",
            },
            {type: "line", value: ""},
            {
              type: "table",
              value: {
                headers: [
                  "Name",
                  "Key",
                  "Join Code",
                ],
                rows: [
                  [
                    invited_org.name,
                    invited_org.key,
                    "join-abc123",
                  ],
                ],
              },
            },
            {type: "line", value: ""},
            {
              type: "line",
              value: "To join an invited org, use: webhookdb org join <join code>.",
            },
          ),
        )
    end

    it "returns correct 'block' information for a customer with only verified memberships" do
      invited_membership.destroy

      get "/v1/me/organization_memberships", active_org_identifier: org.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          blocks: contain_exactly(
            {
              type: "line",
              value: "You are a member of the following organizations:",
            },
            {type: "line", value: ""},
            {
              type: "table",
              value: {
                headers: [
                  "Name",
                  "Key",
                  "Role",
                  "Status",
                ],
                rows: [
                  [
                    org.name,
                    org.key,
                    membership.status,
                    "active",
                  ],
                ],
              },
            },
          ),
        )
    end

    it "returns correct 'block' information for a customer with only unverified (invited) memberships" do
      membership.destroy

      get "/v1/me/organization_memberships", active_org_identifier: "qwerty" # testing with invalid identifier

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          blocks: contain_exactly(
            {
              type: "line",
              value: "You have been invited to the following organizations:",
            },
            {type: "line", value: ""},
            {
              type: "table",
              value: {
                headers: [
                  "Name",
                  "Key",
                  "Join Code",
                ],
                rows: [
                  [
                    invited_org.name,
                    invited_org.key,
                    "join-abc123",
                  ],
                ],
              },
            },
            {type: "line", value: ""},
            {
              type: "line",
              value: "To join an invited org, use: webhookdb org join <join code>.",
            },
          ),
        )
    end

    it "returns correct 'block' information for a customer with no memberships" do
      membership.destroy
      invited_membership.destroy

      get "/v1/me/organization_memberships"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          blocks: contain_exactly(
            {
              type: "line",
              value: "You aren't affiliated with any organizations yet.",
            },
          ),
        )
    end
  end
end
