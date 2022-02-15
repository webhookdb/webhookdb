# frozen_string_literal: true

require "webhookdb/api/db"

RSpec.describe Webhookdb::API::Db, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.in_org(org, verified: true).create }
  let(:admin_role) { Webhookdb::Role.create(name: "admin") }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/db/:organization_key/connection" do
    before(:each) do
      org.update(
        readonly_connection_url_raw: "postgres://readonly:l33t@somehost:5555/mydb",
        admin_connection_url_raw: "postgres://admin:l33t@somehost:5555/mydb",
      )
    end

    it "returns the connection string" do
      get "/v1/db/#{org.key}/connection"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(connection_url: "postgres://readonly:l33t@somehost:5555/mydb")
    end
  end

  describe "GET /v1/db/:organization_key/tables" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1") }

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "returns a list of all tables in org" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table

      get "/v1/db/#{org.key}/tables"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(tables: contain_exactly("fake_v1"))
    end
  end

  describe "POST /v1/db/:organization_key/sql" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1") }
    let(:insert_query) { "INSERT INTO fake_v1 (my_id, data) VALUES ('abcxyz', '{}')" }

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "returns results of sql query" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table
      svc.admin_dataset do |ds|
        ds.db << insert_query
      end

      post "/v1/db/#{org.key}/sql", query: "select * from fake_v1"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        columns: ["pk", "my_id", "at", "data"],
        rows: [[be_a(Numeric), "abcxyz", nil, {}]],
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

  describe "GET /v1/db/:organization_key/roll-credentials" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "modifies the database credentials and updates the org" do
      customer.memberships_dataset.first.update(membership_role: admin_role)
      original_ro = org.readonly_connection_url

      post "/v1/db/#{org.key}/roll_credentials", guard_confirm: true

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(connection_url: not_eq(original_ro))
      expect(org.refresh).to have_attributes(readonly_connection_url: not_eq(original_ro))
    end

    it "requires admin" do
      post "/v1/db/#{org.key}/roll_credentials", guard_confirm: false

      expect(last_response).to have_status(400)
    end

    it "errors if guard_confirm is not given" do
      customer.memberships_dataset.first.update(membership_role: admin_role)

      post "/v1/db/#{org.key}/roll_credentials"

      expect(last_response).to have_status(426)
    end
  end

  describe "POST /v1/db/:org_identifier/fdw" do
    let(:params) { {remote_server_name: "svr", fetch_size: "1", local_schema: "sch", view_schema: "vw"} }

    before(:each) do
      org.update(
        readonly_connection_url_raw: "postgres://me:l33t@somehost:5555/mydb",
        admin_connection_url_raw: "postgres://invalidurl",
      )
    end

    it "generates an FDW response" do
      post "/v1/db/#{org.key}/fdw", **params

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(
          :fdw_sql,
          :views,
          :views_sql,
          :compound_sql,
          # No views so trails with three newlines
          message: start_with("CREATE EXTENSION").and(end_with("vw;\n\n\n")),
        )
    end

    it "can return views sql message" do
      post "/v1/db/#{org.key}/fdw", message_views: true, **params

      expect(last_response).to have_status(200)
      # No service integrations so no message
      expect(last_response).to have_json_body.that_includes(message: "")
    end

    it "can return only fdw sql message" do
      post "/v1/db/#{org.key}/fdw", message_fdw: true, **params

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: start_with("CREATE EXTENSION").and(end_with("vw;\n")))
    end
  end
end
