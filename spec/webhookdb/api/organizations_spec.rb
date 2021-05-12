# frozen_string_literal: true

require "webhookdb/api/organizations"

RSpec.describe Webhookdb::API::Organizations, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  before(:each) do
    Webhookdb::Services::Fake.reset
  end
  after(:each) do
    Webhookdb::Services::Fake.reset
  end

  let!(:test_customer) { Webhookdb::Fixtures.customer.create }
  let!(:test_org) { Webhookdb::Fixtures.organization.create }

  describe "GET /v1/organizations" do
    it "returns all organizations associated with customer" do
      orgs = Array.new(2) { Webhookdb::Fixtures.organization.create }
      _extra_org = Webhookdb::Fixtures.organization.create

      orgs.each { |o| Webhookdb::OrganizationMembership.create(customer_id: test_customer.id, organization_id: o.id) }

      get "/v1/organizations", customer_id: test_customer.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        of_length(2)
    end

    it "returns a message if customer has no organizations" do
      get "/v1/organizations", customer_id: test_customer.id

      expect(last_response).to have_status(200)
      expect(last_response).to match("You aren't affiliated with any organizations yet.")
    end
  end

  describe "GET /v1/organizations/members" do
    it "returns all customers associated with organization" do
      extra_customers = Array.new(3) { Webhookdb::Fixtures.customer.create }

      test_org.add_organization_membership(customer: test_customer)
      extra_customers.each { |c| test_org.add_organization_membership(customer: c) }

      expect(Webhookdb::OrganizationMembership.count).to eq(4)
      puts Webhookdb::OrganizationMembership.select(:organization_id, :customer_id)

      get "/v1/organizations/members", customer_id: test_customer.id, organization_id: test_org.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        of_length(4)
    end

    it "returns a message if customer has no organizations" do
      get "/v1/organizations/members", customer_id: test_customer.id, organization_id: test_org.id

      expect(last_response).to have_status(403)
      expect(last_response).to match("You don't have permissions with that organization.")
    end
  end
end
