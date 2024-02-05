# frozen_string_literal: true

require "webhookdb/api/custom_queries"

RSpec.describe Webhookdb::API::CustomQueries, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let(:customer) { Webhookdb::Fixtures.customer.create }
  let(:org) { Webhookdb::Fixtures.organization.with_member(customer).create }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:key/custom_queries" do
    it "returns a list of custom queries for the organization" do
      custom_query = Webhookdb::Fixtures.custom_query(organization: org).create
      Webhookdb::Fixtures.custom_query.create

      get "/v1/organizations/#{org.key}/custom_queries"

      expect(last_response.status).to eq(200)
      expect(last_response).to have_json_body.
        that_includes(items: contain_exactly(include(id: custom_query.opaque_id)))
    end

    it "returns a message if organization has no custom queries" do
      new_org = Webhookdb::Fixtures.organization.with_member(customer).create
      get "/v1/organizations/#{new_org.key}/custom_queries"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.
        that_includes(message: include("have any saved queries"))
    end
  end

  describe "POST /v1/organizations/:key/custom_queries/create" do
    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "creates a custom query" do
      post "/v1/organizations/#{org.key}/custom_queries/create", description: "myq", sql: "SELECT 1"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        description: "myq",
        sql: "SELECT 1",
        public: false,
      )
      expect(org.custom_queries).to contain_exactly(
        have_attributes(created_by: customer, sql: "SELECT 1", public: false),
      )
    end

    it "fails if the SQL cannot be run" do
      post "/v1/organizations/#{org.key}/custom_queries/create", description: "myq", sql: "SELECT invalid"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(state_machine_step: include(prompt: /new query/, output: /was invalid/)),
      )
    end

    it "can create a public query" do
      post "/v1/organizations/#{org.key}/custom_queries/create", description: "myq", sql: "SELECT 1", public: true

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(public: true)
      expect(org.custom_queries).to contain_exactly(have_attributes(public: true))
    end
  end

  describe "GET /v1/organizations/:key/custom_queries/:id" do
    it "returns the custom query" do
      cq = Webhookdb::Fixtures.custom_query(organization: org).create

      get "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        sql: "SELECT * FROM mytable",
        id: cq.opaque_id,
        message: include("to see how to"),
      )
    end

    it "403s if the query with the given opaque id does not exist" do
      cq = Webhookdb::Fixtures.custom_query.create

      get "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("There is no saved query with that")),
      )
    end
  end

  describe "GET /v1/organizations/:key/custom_queries/:id/run" do
    it "runs the query with the given opaque id and returns results" do
      org.prepare_database_connections

      sint = Webhookdb::Fixtures.service_integration.create(organization: org, table_name: "fake_v1")
      sint.replicator.create_table
      sint.replicator.admin_dataset do |ds|
        ds.db << "INSERT INTO fake_v1 (my_id, data) VALUES ('abcxyz', '{}')"
      end

      cq = Webhookdb::Fixtures.custom_query.create(organization: org, sql: "SELECT * FROM fake_v1")

      get "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/run"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        headers: ["pk", "my_id", "at", "data"],
        rows: [[be_a(Numeric), "abcxyz", nil, {}]],
      )
    ensure
      org.remove_related_database
    end

    it "400s if the query fails" do
      org.prepare_database_connections
      cq = Webhookdb::Fixtures.custom_query.create(organization: org, sql: "SELECT invalid")

      get "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/run"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(error: include(message: /Something went wrong/))
    ensure
      org.remove_related_database
    end

    it "403s if the query with the given opaque id does not exist" do
      get "/v1/organizations/#{org.key}/custom_queries/abc/run"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /There is no saved query with that/),
      )
    end
  end

  describe "POST /v1/organizations/:key/custom_queries/:id/update" do
    let(:custom_query) { Webhookdb::Fixtures.custom_query(organization: org, created_by: customer).create }

    it "prompts for field" do
      post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.
        that_includes(error: include(
          state_machine_step: include(prompt: include("like to update (one of: description, sql, public):")),
        ))
    end

    it "prompts for value" do
      post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update", field: "description"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.
        that_includes(error: include(state_machine_step: include(prompt: "What is the new value? ")))
    end

    it "403s if request customer isn't the person who created the query or an admin" do
      other_cq = Webhookdb::Fixtures.custom_query(organization: org).create

      post "/v1/organizations/#{org.key}/custom_queries/#{other_cq.opaque_id}/update",
           field: "description", value: "foobar"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You must be the query's creator or an org admin."),
      )
    end

    it "succeeds if the request customer is an org admin" do
      other_cq = Webhookdb::Fixtures.custom_query(organization: org).create
      customer.verified_memberships.first.update(membership_role: Webhookdb::Role.admin_role)

      post "/v1/organizations/#{org.key}/custom_queries/#{other_cq.opaque_id}/update",
           field: "description", value: "foobar"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(message: include("on saved query"))
      expect(other_cq.refresh).to have_attributes(description: "foobar")
    end

    it "400s if field is not editable via the cli" do
      post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update", field: "id", value: "123"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: include("That field is not editable.")),
      )
    end

    it "updates the saved query" do
      post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
           field: "description", value: "foobar"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: "You have updated 'description' on saved query '#{custom_query.opaque_id}'.",
        description: "foobar",
      )
      expect(custom_query.refresh).to have_attributes(description: "foobar")
    end

    describe "setting the 'public' field" do
      it "can set it to true" do
        post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
             field: "public", value: "on"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(public: true)
        expect(custom_query.refresh).to have_attributes(public: true)
      end

      it "can set it to false" do
        custom_query.update(public: true)
        post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
             field: "public", value: "off"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(public: false)
        expect(custom_query.refresh).to have_attributes(public: false)
      end

      it "errors with a clear message if the boolean string is invalid" do
        post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
             field: "public", value: "-"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(state_machine_step: include(prompt: include("unparseable bool:"))),
        )
      end
    end

    describe "setting the 'sql' field" do
      before(:each) do
        org.prepare_database_connections
      end

      after(:each) do
        org.remove_related_database
      end

      it "422s if the field is sql and the value is not a valid query" do
        post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
             field: "sql", value: "SELECT invalid"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.
          that_includes(error: include(state_machine_step: include(output: /went wrong/, prompt: /Enter your query/)))
      end

      it "sets it if valid" do
        post "/v1/organizations/#{org.key}/custom_queries/#{custom_query.opaque_id}/update",
             field: "sql", value: "SELECT 503"

        expect(last_response).to have_status(200)
        expect(custom_query.refresh).to have_attributes(sql: "SELECT 503")
      end
    end

    it "403s if the query does not belong to the org or does not exist" do
      cq = Webhookdb::Fixtures.custom_query.create

      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/update",
           field: "name", value: "foobar"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /There is no saved query with that id/),
      )
    end
  end

  describe "POST /v1/organizations/:key/custom_queries/:opaque_id/info" do
    let(:cq) { Webhookdb::Fixtures.custom_query(organization: org).create }

    before(:each) do
      login_as(customer)
    end

    it "returns all fields if none are given" do
      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/info"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        blocks: include(
          include(
            type: "table",
            value: include(
              headers: ["Field", "Value"],
              rows: include(["Description", cq.description]),
            ),
          ),
        ),
      )
    end

    it "returns opaque_id if asked for `id`" do
      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/info", field: "id"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        blocks: [
          {
            type: "line",
            value: cq.opaque_id,
          },
        ],
      )
    end

    it "returns directly-mapped field names like sql and public" do
      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/info", field: "public"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        blocks: [
          {
            type: "line",
            value: false,
          },
        ],
      )
    end

    it "400s if asked about an unsupported field" do
      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/info", field: "organization_id"
      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: match("Field does not have a valid value")),
      )
    end
  end

  describe "POST /v1/organizations/:key/custom_queries/:id/delete" do
    it "403s if request customer isn't the person who created the query or an admin" do
      other_query = Webhookdb::Fixtures.custom_query(organization: org).create
      post "/v1/organizations/#{org.key}/custom_queries/#{other_query.opaque_id}/delete"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You must be the query's creator or an org admin."),
      )
    end

    it "deletes the query and returns correct response" do
      cq = Webhookdb::Fixtures.custom_query(organization: org, created_by: customer).create

      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/delete"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        message: /You have successfully deleted the saved query /,
      )
      expect(cq).to be_destroyed
    end

    it "403s if the query does not belong to the org or does not exist" do
      cq = Webhookdb::Fixtures.custom_query.create

      post "/v1/organizations/#{org.key}/custom_queries/#{cq.opaque_id}/delete"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /There is no saved query with that id/),
      )
    end
  end

  describe "GET /v1/custom_queries/:opaque_id/run" do
    let(:cq) { Webhookdb::Fixtures.custom_query(organization: org, sql: "SELECT 1 as c1, 2 as c2").create }

    before(:each) do
      logout
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "403s if no query with an id exists" do
      get "/v1/custom_queries/123/run"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(message: "Forbidden"))
    end

    it "400s if the query is invalid (do not expose info to the public)" do
      header "Whdb-Sha256-Conn", Digest::SHA256.hexdigest(org.readonly_connection_url)
      cq.update(sql: "SELECT invalid")

      get "/v1/custom_queries/#{cq.opaque_id}/run"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Something went wrong running the query."))
    end

    describe "with connection string auth" do
      it "succeeds when valid for the custom query org" do
        header "Whdb-Sha256-Conn", Digest::SHA256.hexdigest(org.readonly_connection_url)

        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          headers: ["c1", "c2"],
          rows: [[1, 2]],
        )
      end

      it "403s if invalid for the custom query org" do
        header "Whdb-Sha256-Conn", "foo"

        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(error: include(message: "Forbidden"))
      end
    end

    describe "with normal auth" do
      before(:each) do
        login_as(customer)
      end

      it "succeeds when the current customer can access the query" do
        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          headers: ["c1", "c2"],
          rows: [[1, 2]],
        )
      end

      it "403s if the current customer cannot access the query" do
        customer.verified_memberships.first.destroy

        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(error: include(message: "Forbidden"))
      end
    end

    describe "without auth" do
      it "succeeds if the query is public" do
        cq.update(public: true)

        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          headers: ["c1", "c2"],
          rows: [[1, 2]],
        )
      end

      it "403s if the query is private" do
        get "/v1/custom_queries/#{cq.opaque_id}/run"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(error: include(message: "Forbidden"))
      end
    end
  end
end
