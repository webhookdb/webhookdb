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

  describe "GET /v1/services/:name/fixtures" do
    it "returns fixture sql" do
      get "/v1/services/fake_v1/fixtures"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        schema_sql: include("CREATE TABLE fake_v1_fixture"),
      )
    end
    it "403s if the service does not exist" do
      get "/v1/services/nopers/fixtures"

      expect(last_response).to have_status(403)
    end
  end
end
