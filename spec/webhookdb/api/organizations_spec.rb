# frozen_string_literal: true

require "webhookdb/api/organizations"

RSpec.describe Webhookdb::API::Organizations, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create}

  describe "GET /v1/organizations" do
    it "returns all organizations associated with customer" do
      orgs = Array.new(2) { Webhookdb::Fixtures.organization.create }
      _extra_org = Webhookdb::Fixtures.organization.create

      orgs.each { |o| customer.add_organization(o) }

      get "/v1/organizations", customer_id: customer.id

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        of_length(2)
    end
  end
end

