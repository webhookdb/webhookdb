# frozen_string_literal: true

require "webhookdb/api/sync_targets"

RSpec.describe Webhookdb::API::SyncTargets, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.admin_in_org(org).create }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, service_name: "fake_v1") }
  let(:membership) { customer.all_memberships_dataset.last }
  let(:valid_pg_url) { Webhookdb::Postgres::Model.uri }

  before(:each) do
    login_as(customer)
  end

  describe "db sync target endpoints" do
    describe "GET /v1/organizations/:identifier/sync_targets/db" do
      it "returns the sync targets for the org and any service integrations" do
        sint_stgt = Webhookdb::Fixtures.sync_target.create(
          service_integration: sint, connection_url: "postgres://user:password@foo.bar/spam",
        )

        get "/v1/organizations/#{org.key}/sync_targets/db"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          items: have_same_ids_as(sint_stgt).pk_field(:opaque_id),
        )
        expect(last_response).to have_json_body.that_includes(
          items: contain_exactly(include(connection_url: "postgres://***:***@foo.bar/spam")),
        )
      end

      it "returns a message if there are no targets" do
        get "/v1/organizations/#{org.key}/sync_targets/db"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          items: [],
          message: include("has no database sync targets set up"),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/db/create" do
      it "creates the sync target for service integration" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: valid_pg_url,
             period_seconds: 600

        expect(last_response).to have_status(200)
        stgt = sint.sync_targets.first
        expect(stgt).to have_attributes(
          connection_url: valid_pg_url,
          period_seconds: 600,
          table: "",
          schema: "",
          page_size: 200, # the default
        )
      end

      it "prompts for connection_url" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_opaque_id: sint.opaque_id

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.
          that_includes(error: include(state_machine_step: include(prompt: match("database connection string"))))
      end

      it "prompts for period_seconds" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_opaque_id: sint.opaque_id,
             connection_url: "postgres://u:p@a.b"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.
          that_includes(error: include(state_machine_step: include(post_params_value_key: "period_seconds")))
      end

      it "can specify all fields" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: valid_pg_url,
             table: "mytbl",
             schema: "my_schema",
             period_seconds: 11.minutes.to_i

        expect(last_response).to have_status(200)
        stgt = sint.sync_targets.first
        expect(stgt).to have_attributes(
          period_seconds: 11.minutes.to_i,
          table: "mytbl",
          schema: "my_schema",
        )
      end

      it "can use deprecated 'service_integration_opaque_id' parameter" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_opaque_id: sint.opaque_id,
             connection_url: valid_pg_url,
             period_seconds: 600

        expect(last_response).to have_status(200)
      end

      it "prefers 'service_integration_identifier' over 'service_integration_opaque_id' parameter" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             service_integration_opaque_id: "fakesint",
             connection_url: valid_pg_url,
             period_seconds: 600

        # if the deprecated param were used, this would be a 403 integration not found
        expect(last_response).to have_status(200)
      end

      it "errors if no service integration id parameter has been submitted" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             connection_url: valid_pg_url,
             period_seconds: 600

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: match("at least one parameter must be provided")),
        )
      end

      it "403s if service integration with given identifier doesn't exist" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: "fakesint", connection_url: "postgres://u:p@a.b", period_seconds: 600

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no service integration with that identifier."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id, connection_url: "postgres://u:p@a.b", period_seconds: 600

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end

      it "400s if the url fails validation because db protocol is unsupported" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "superdb://a.b",
             table: "mytbl",
             schema: "my_schema",
             period_seconds: 11.minutes.to_i

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: /The 'superdb' protocol is not supported for database sync targets/),
        )
      end

      it "400s if the url fails validation because it is an https url" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             table: "mytbl",
             schema: "my_schema",
             period_seconds: 11.minutes.to_i

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: /The 'https' protocol is not supported for database sync targets/),
        )
      end

      it "400s if the period is outside the allowed range" do
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "postgres://u:p@x/b",
             period_seconds: 1

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(
            message: /The valid sync period for organization .* is between 600 and 86400 seconds/,
          ),
        )
      end

      it "200s if the period is outside the default range but the org setting allows it" do
        org.update(minimum_sync_seconds: 1)
        post "/v1/organizations/#{org.key}/sync_targets/db/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: valid_pg_url,
             period_seconds: 1

        expect(last_response).to have_status(200)
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/db/:opaque_id/update_credentials" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
      end

      it "updates the username and password" do
        # get valid values
        uri = URI(valid_pg_url)
        user = uri.user
        pass = uri.password

        # then update sync target with old values
        uri.user = "old_user"
        uri.password = "old_pass"
        sync_tgt.update(connection_url: uri.to_s)

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/update_credentials",
             user:, password: pass

        expect(last_response).to have_status(200)
        expect(sync_tgt.refresh).to have_attributes(connection_url: valid_pg_url)
      end

      it "403s if the sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/db/#{st.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no database sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization associated with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end

      it "400s if new creds are invalid" do
        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: start_with("Could not SELECT 1: could not translate host")),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/db/:opaque_id/update" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
      end

      it "can modify period, schema, and table" do
        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/update",
             table: "tbl2", schema: "sch2", period_seconds: 2.hours.to_i

        expect(last_response).to have_status(200)
        expect(sync_tgt.refresh).to have_attributes(
          table: "tbl2",
          schema: "sch2",
          period_seconds: 2.hours.to_i,
        )
      end

      it "403s if the sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/db/#{st.opaque_id}/update", table: "tbl"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no database sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/update", table: "tbl"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/db/:opaque_id/delete" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
      end

      it "deletes the sync target" do
        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/delete",
             confirm: " #{sync_tgt.service_integration.table_name} \n"

        expect(last_response).to have_status(200)
        expect(Webhookdb::SyncTarget.all).to be_empty
      end

      it "422s if the table name is not given as the confirmation value" do
        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/delete"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(code: "prompt_required_params"),
        )

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/delete", confirm: sync_tgt.table + "x"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(code: "prompt_required_params"),
        )
      end

      it "403s if the sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/db/#{st.opaque_id}/delete", confirm: " #{sync_tgt.table} \n"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no database sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/delete",
             confirm: " #{sync_tgt.table} \n"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/db/:opaque_id/sync" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
      end

      it "scheduled the sync job", sidekiq: :fake do
        Timecop.freeze("2022-05-05T10:00:00Z") do
          sync_tgt.update(last_synced_at: 3.minutes.ago)

          post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/sync"
          expect(last_response).to have_status(200)
          expect(last_response).to have_json_body.
            that_includes(message: /start at about 2022-05-05 10:07:00 \+0000/)

          expect(Sidekiq).to have_queue("netout").consisting_of(
            job_hash(
              Webhookdb::Jobs::SyncTargetRunSync,
              at: match_time("2022-05-05T10:07:00Z"),
              args: [sync_tgt.id],
            ),
          )
        end
      end

      it "403s if the sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/db/#{st.opaque_id}/sync"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no database sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/db/#{sync_tgt.opaque_id}/sync"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end
  end

  describe "http sync target endpoints" do
    describe "GET /v1/organizations/:identifier/sync_targets/http" do
      it "returns the HTTP sync targets for the org and any service integrations" do
        sint_stgt = Webhookdb::Fixtures.sync_target.create(
          service_integration: sint, connection_url: "https://u:p@a.b",
        )

        get "/v1/organizations/#{org.key}/sync_targets/http"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          items: have_same_ids_as(sint_stgt).pk_field(:opaque_id),
        )
        expect(last_response).to have_json_body.that_includes(
          items: contain_exactly(include(connection_url: "https://***:***@a.b")),
        )
      end

      it "returns a message if there are no targets" do
        get "/v1/organizations/#{org.key}/sync_targets/http"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          items: [],
          message: include("has no http sync targets set up"),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/http/create" do
      it "creates the HTTP sync target for service integration" do
        req = stub_request(:post, "https://a.b/").
          with(
            body: {
              rows: [],
              integration_id: "svi_test",
              integration_service: "httpsync_test",
              table: "test",
            },
          ).
          to_return(status: 200, body: "", headers: {})

        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             period_seconds: 600

        expect(last_response).to have_status(200)
        stgt = sint.sync_targets.first
        expect(stgt).to have_attributes(
          connection_url: "https://u:p@a.b",
          period_seconds: 600,
          table: "",
          schema: "",
        )
        expect(req).to have_been_made
      end

      it "prompts for connection_url" do
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_opaque_id: sint.opaque_id

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.
          that_includes(error: include(state_machine_step: include(prompt: match("HTTP endpoint"))))
      end

      it "prompts for period_seconds" do
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.
          that_includes(error: include(state_machine_step: include(post_params_value_key: "period_seconds")))
      end

      it "can specify all fields" do
        req = stub_request(:post, "https://a.b/").
          with(
            body: {
              rows: [],
              integration_id: "svi_test",
              integration_service: "httpsync_test",
              table: "test",
            },
          ).
          to_return(status: 200, body: "", headers: {})
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             period_seconds: 11.minutes.to_i,
             page_size: 600

        expect(last_response).to have_status(200)
        stgt = sint.sync_targets.first
        expect(stgt).to have_attributes(
          period_seconds: 11.minutes.to_i,
          page_size: 600,
        )
        expect(req).to have_been_made
      end

      it "403s if service integration with given identifier doesn't exist" do
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: "fakesint",
             connection_url: "https://user:pass@example.com",
             period_seconds: 600

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no service integration with that identifier."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://user:pass@example.com",
             period_seconds: 600

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end

      it "400s if the url fails initial validation" do
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "postgres://a.b",
             table: "mytbl",
             schema: "my_schema",
             period_seconds: 11.minutes.to_i

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: /Must be an https url/),
        )
      end

      it "400s if the url verification request doesn't go through" do
        req = stub_request(:post, "https://a.b/").
          with(
            body: {
              rows: [],
              integration_id: "svi_test",
              integration_service: "httpsync_test",
              table: "test",
            },
          ).
          to_return(status: 402, body: "", headers: {})

        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             period_seconds: 600

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.
          that_includes(
            error: include(message: start_with("POST to https://a.b failed: HttpError(status: 402")),
          )
        expect(sint.sync_targets).to be_empty
        expect(req).to have_been_made
      end

      it "400s if the period is outside the allowed range" do
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             period_seconds: 1

        expect(last_response).to have_status(400)
        expect(last_response).to have_json_body.that_includes(
          error: include(
            message: /The valid sync period for organization .* is between 600 and 86400 seconds/,
          ),
        )
      end

      it "200s if the period is outside the default range but the org setting allows it" do
        org.update(minimum_sync_seconds: 1)
        req = stub_request(:post, "https://a.b/").
          with(
            body: {
              rows: [],
              integration_id: "svi_test",
              integration_service: "httpsync_test",
              table: "test",
            },
          ).
          to_return(status: 200, body: "", headers: {})
        post "/v1/organizations/#{org.key}/sync_targets/http/create",
             service_integration_identifier: sint.opaque_id,
             connection_url: "https://u:p@a.b",
             period_seconds: 1

        expect(last_response).to have_status(200)
        expect(req).to have_been_made
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/http/:opaque_id/update_credentials" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "https://u:p@a.b")
      end

      it "updates the username and password" do
        req = stub_request(:post, "https://a.b/").
          with(
            body: {
              rows: [],
              integration_id: "svi_test",
              integration_service: "httpsync_test",
              table: "test",
            },
          ).
          to_return(status: 200, body: "", headers: {})

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(200)
        expect(sync_tgt.refresh).to have_attributes(connection_url: "https://user:pass@a.b")
        expect(req).to have_been_made
      end

      it "403s if the HTTP sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/http/#{st.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no http sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/update_credentials",
             user: "user", password: "pass"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/http/:opaque_id/update" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "https://u:p@a.b")
      end

      it "can modify period" do
        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/update", period_seconds: 2.hours.to_i

        expect(last_response).to have_status(200)
        expect(sync_tgt.refresh).to have_attributes(
          period_seconds: 2.hours.to_i,
        )
      end

      it "can modify page_size" do
        http_tgt = Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "https://u:p@a.b")
        post "/v1/organizations/#{org.key}/sync_targets/http/#{http_tgt.opaque_id}/update", page_size: 750

        expect(last_response).to have_status(200)
        expect(http_tgt.refresh).to have_attributes(page_size: 750)
      end

      it "403s if the HTTP sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/http/#{st.opaque_id}/update", table: "tbl"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no http sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization associated with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/update", table: "tbl"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/http/:opaque_id/delete" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "https://u:p@a.b")
      end

      it "deletes the HTTP sync target" do
        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/delete",
             confirm: " #{sync_tgt.service_integration.table_name} \n"

        expect(last_response).to have_status(200)
        expect(Webhookdb::SyncTarget.all).to be_empty
      end

      it "422s if the table name is not given as the confirmation value" do
        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/delete"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(code: "prompt_required_params"),
        )

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/delete",
             confirm: sync_tgt.table + "x"

        expect(last_response).to have_status(422)
        expect(last_response).to have_json_body.that_includes(
          error: include(code: "prompt_required_params"),
        )
      end

      it "403s if the HTTP sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/http/#{st.opaque_id}/delete", confirm: " #{sync_tgt.table} \n"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no http sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/delete",
             confirm: " #{sync_tgt.table} \n"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end

    describe "POST /v1/organizations/:identifier/sync_targets/http/:opaque_id/sync" do
      let(:sync_tgt) do
        Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "https://u:p@a.b")
      end

      it "scheduled the sync job", sidekiq: :fake do
        Timecop.freeze("2022-05-05T10:00:00Z") do
          sync_tgt.update(last_synced_at: 3.minutes.ago)
          post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/sync"
          expect(last_response).to have_status(200)
          expect(last_response).to have_json_body.
            that_includes(message: "Http sync has been scheduled. It should start at about 2022-05-05 10:07:00 +0000.")
          expect(Sidekiq).to have_queue("netout").consisting_of(
            job_hash(Webhookdb::Jobs::SyncTargetRunSync, args: [sync_tgt.id], at: match_time("2022-05-05T10:07:00Z")),
          )
        end
      end

      it "403s if the HTTP sync target does not exist for that org" do
        st = Webhookdb::Fixtures.sync_target.create
        post "/v1/organizations/#{org.key}/sync_targets/http/#{st.opaque_id}/sync"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "There is no http sync target with that id."),
        )
      end

      it "403s if user doesn't have permissions for organization assocatied with service integration" do
        membership.destroy

        post "/v1/organizations/#{org.key}/sync_targets/http/#{sync_tgt.opaque_id}/sync"

        expect(last_response).to have_status(403)
        expect(last_response).to have_json_body.that_includes(
          error: include(message: "You don't have permissions with that organization."),
        )
      end
    end
  end
end
