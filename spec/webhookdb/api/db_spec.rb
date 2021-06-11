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
    org.prepare_database_connections
  end

  after(:each) do
    org.remove_related_database
  end

  describe "GET /v1/db/:organization_key" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1") }

    it "returns a list of all tables in org" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table

      get "/v1/db/#{org.key}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(tables: contain_exactly("fake_v1"))
    end
  end

  describe "POST /v1/db/:organization_key/sql" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1") }
    let(:insert_query) { "INSERT INTO fake_v1 (my_id, data) VALUES ('abcxyz', '{}')" }

    it "returns results of sql query" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table
      svc.admin_dataset do |ds|
        ds.db << insert_query
      end

      post "/v1/db/#{org.key}/sql", query: "select * from fake_v1"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        columns: ["pk", "data", "my_id", "at"],
        rows: [[be_a(Numeric), {}, "abcxyz", nil]],
      )
    end

    it "errors for a query for which permissions are missing" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table

      post "/v1/db/#{org.key}/sql", query: insert_query

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You do not have permission to perform this query. Queries must be read-only."),
      )
    end
  end
end
