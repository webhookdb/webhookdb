# frozen_string_literal: true

require "webhookdb/api/db"

RSpec.describe Webhookdb::API::Db, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer: customer, verified: true) }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/db/:organization_key" do
    it "returns a list of all tables in org" do
      sint = Webhookdb::ServiceIntegration.create(organization: org, service_name: "fake_v1", table_name: "fake_v1",
                                                  opaque_id: SecureRandom.hex(6),)
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table

      get "/v1/db/#{org.key}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(tables: include("fake_v1"))
    end
  end

  describe "GET /v1/db/:organization_key/sql" do
    it "returns results of sql query" do
      sint = Webhookdb::ServiceIntegration.create(organization: org, service_name: "fake_v1", table_name: "fake_v1",
                                                  opaque_id: SecureRandom.hex(6),)
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table
      query = 'INSERT INTO fake_v1 (my_id, data) VALUES (\'abcxyz\', \'{}\'); '
      sint.db << query

      get "/v1/db/#{org.key}/sql", query: "select * from fake_v1"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(columns: ['pk', 'data', 'my_id', 'at'], rows: [[be_a(Numeric), {}, "abcxyz", nil]])
    end
  end
end
