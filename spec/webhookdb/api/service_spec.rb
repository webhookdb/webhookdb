# frozen_string_literal: true

require "webhookdb/api/services"
require "webhookdb/admin_api/entities"

RSpec.describe Webhookdb::API::Services, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/services" do
    it "returns a list of all available services" do
      get "/v1/services"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(items: include(include(name: "shopify_customer_v1")))
    end
  end
end
