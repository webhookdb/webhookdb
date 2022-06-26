# frozen_string_literal: true

require "webhookdb/api/db"
require "webhookdb/jobs/organization_database_migration_run"

RSpec.describe Webhookdb::API::Db, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.verified_in_org(org).create }
  let(:admin_role) { Webhookdb::Role.admin_role }
  let(:non_admin_role) { Webhookdb::Role.non_admin_role }

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

  describe "POST /v1/db/:organization_key/migrate_database" do
    before(:each) do
      Webhookdb::Organization::DbBuilder.allow_public_migrations = true
      customer.all_memberships_dataset.first.update(membership_role: admin_role)
      org.update(
        admin_connection_url_raw: "postgres://x:y@orig/db",
        readonly_connection_url_raw: "postgres://x:y@orig/db",
      )
    end

    it "prompts for admin url" do
      post "/v1/db/#{org.key}/migrate_database"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.
        that_includes(
          error: include(
            code: "prompt_required_params",
            state_machine_step: include(
              prompt_is_secret: true,
              prompt: match("administrative operations on your database"),
            ),
          ),
        )
    end

    it "prompts for readonly url" do
      post "/v1/db/#{org.key}/migrate_database", admin_url: "postgres://admin:l33t@somehost:5555/mydb"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.
        that_includes(
          error: include(
            code: "prompt_required_params",
            state_machine_step: include(
              prompt_is_secret: true,
              prompt: match("READONLY Postgres connection URL"),
            ),
          ),
        )
    end

    it "create a database migration, updates org, and returns message" do
      post "/v1/db/#{org.key}/migrate_database", admin_url: "postgres://admin:l33t@somehost:5555/mydb",
                                                 readonly_url: "postgres://readonly:l33t@somehost:5555/mydb"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: include("has been enqueued"))
      expect(org.refresh).to have_attributes(
        admin_connection_url_raw: "postgres://admin:l33t@somehost:5555/mydb",
        readonly_connection_url_raw: "postgres://readonly:l33t@somehost:5555/mydb",
      )
      expect(org.database_migrations).to contain_exactly(
        have_attributes(
          source_admin_connection_url: "postgres://x:y@orig/db",
          destination_admin_connection_url: "postgres://admin:l33t@somehost:5555/mydb",
        ),
      )
    end

    it "uses admin url for readonly url if readonly url is not provided" do
      post "/v1/db/#{org.key}/migrate_database", admin_url: "postgres://admin:l33t@somehost:5555/mydb",
                                                 readonly_url: ""

      expect(last_response).to have_status(200)
      expect(org.refresh).to have_attributes(
        admin_connection_url_raw: "postgres://admin:l33t@somehost:5555/mydb",
        readonly_connection_url_raw: "postgres://admin:l33t@somehost:5555/mydb",
      )
    end

    it "errors if not org admin" do
      customer.all_memberships_dataset.first.update(membership_role: non_admin_role)
      post "/v1/db/#{org.key}/migrate_database", admin_url: "admin_url", readonly_url: "url"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("You don't have admin privileges with #{org.name}")),
      )
    end

    it "409s if a migration is in progress" do
      _ongoing_dbm = Webhookdb::Fixtures.organization_database_migration.with_organization(org).with_urls.started.create
      post "/v1/db/#{org.key}/migrate_database", admin_url: "admin_url", readonly_url: "url"

      expect(last_response).to have_status(409)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("Organization #{org.name} has an ongoing database host migration")),
      )
    end

    it "errors if public migrations are not enabled" do
      Webhookdb::Organization::DbBuilder.allow_public_migrations = false

      post "/v1/db/#{org.key}/migrate_database"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("Public database migrations are not enabled")),
      )
    end
  end

  describe "GET /v1/db/:organization_key/migrations" do
    it "returns the orgs database migrations" do
      _finished = Webhookdb::Fixtures.organization_database_migration.with_organization(org).with_urls.finished.create
      _started = Webhookdb::Fixtures.organization_database_migration.with_organization(org).with_urls.started.create

      get "/v1/db/#{org.key}/migrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: contain_exactly(
          match(include(status: "in_progress")),
          match(include(status: "finished")),
        ),
      )
    end

    it "returns a message if there are no database migrations" do
      get "/v1/db/#{org.key}/migrations"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: [],
        message: include("has no database migrations"),
      )
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
        headers: ["pk", "my_id", "at", "data"],
        rows: [[be_a(Numeric), "abcxyz", nil, {}]],
      )
    end

    it "has a clear error if the table does not exist" do
      post "/v1/db/#{org.key}/sql", query: "select * from fake_v1"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include('table "fake_v1" does not exist')),
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

    it "otherwise presents the raw Postgres error message" do
      svc = Webhookdb::Services.service_instance(sint)
      svc.create_table

      post "/v1/db/#{org.key}/sql", query: "this is invalid"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "ERROR:  syntax error at or near \"this\"\nLINE 1: this is invalid\n        ^\n"),
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
      customer.all_memberships_dataset.first.update(membership_role: admin_role)
      original_ro = org.readonly_connection_url

      post "/v1/db/#{org.key}/roll_credentials", guard_confirm: true

      expect(last_response).to have_status(200)
      expect(org.refresh).to have_attributes(readonly_connection_url: not_eq(original_ro))
      expect(last_response).to have_json_body.
        that_includes(message: "Your database connection string is now: #{org.refresh.readonly_connection_url_raw}")
    end

    it "requires admin" do
      post "/v1/db/#{org.key}/roll_credentials", guard_confirm: false

      expect(last_response).to have_status(403)
    end

    it "errors if guard_confirm is not given" do
      customer.all_memberships_dataset.first.update(membership_role: admin_role)

      post "/v1/db/#{org.key}/roll_credentials"

      expect(last_response).to have_status(422)
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

    it "also works from the legacy URL" do
      post "/v1/organizations/#{org.key}/fdw", message_fdw: true, **params

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: start_with("CREATE EXTENSION").and(end_with("vw;\n")))
    end
  end
end
