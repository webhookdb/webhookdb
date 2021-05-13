# frozen_string_literal: true

require "webhookdb/api/organizations"

RSpec.describe Webhookdb::API::Organizations, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer: customer) }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations" do
    it "returns all organizations associated with customer" do
      other_org_in = Webhookdb::Fixtures.organization.with_member(customer).create
      _org_not_in = Webhookdb::Fixtures.organization.create

      get "/v1/organizations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(org, other_org_in))
    end

    it "returns a message if customer has no organizations" do
      membership.destroy

      get "/v1/organizations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "You aren't affiliated with any organizations yet.",
      )
    end
  end

  # GET

  describe "GET /v1/organizations/:organization_id/members" do
    it "returns all customers associated with organization" do
      extra_customers = Array.new(3) { Webhookdb::Fixtures.customer.create }
      extra_customers.each { |c| org.add_membership(customer: c) }

      get "/v1/organizations/#{org.id}/members"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_length(4))
    end

    it "403s if the customer is not a member" do
      membership.destroy

      get "/v1/organizations/#{org.id}/members"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "GET v1/organizations/:organization_id/service_integrations" do
    it "returns all service integrations associated with organization" do
      integrations = Array.new(2) { Webhookdb::Fixtures.service_integration.create }
      _extra_integrations = Webhookdb::Fixtures.service_integration.create

      integrations.each { |i| org.add_service_integration(i) }
      get "/v1/organizations/#{org.id}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(items: have_same_ids_as(integrations))
    end

    it "returns a message if org has no service integrations" do
      get "/v1/organizations/#{org.id}/service_integrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: "Organization doesn't have any integrations yet.")
    end
  end

  # POST

  describe "POST v1/organizations/create" do
    it "creates new organization and creates membership for current customer" do
      post "v1/organizations/create", name: "Acme Corporation"

      new_org = Webhookdb::Organization[name: "Acme Corporation"]
      expect(new_org).to_not be_nil
      expect(new_org.key).to eq("acme_corporation")

      expect(new_org.memberships_dataset.where(customer: customer).all).to have_length(1)
    end

    it "returns correct message" do
      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(201)
      expect(last_response).to have_json_body.that_includes(
        message: include("Your organization identifier is: acme_corporation"),
      )
    end

    it "errors if organization key is not unique" do
      Webhookdb::Fixtures.organization(name: "Acme Corporation").create

      post "v1/organizations/create", name: "Acme Corporation"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "An organization with that name already exists."),
      )
    end
  end
end
