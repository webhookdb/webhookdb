# frozen_string_literal: true

require "webhookdb/api/sync_targets"

RSpec.describe Webhookdb::API::SyncTargets, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.admin_in_org(org).create }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, service_name: "fake_v1") }
  let(:membership) { customer.all_memberships_dataset.last }

  before(:each) do
    login_as(customer)
  end

  describe "GET /v1/organizations/:identifier/sync_targets" do
    it "returns the sync targets for the org and any service integrations" do
      sint_stgt = Webhookdb::Fixtures.sync_target.create(
        service_integration: sint, connection_url: "postgres://user:password@foo.bar/spam",
      )

      get "/v1/organizations/#{org.key}/sync_targets"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: have_same_ids_as(sint_stgt).pk_field(:opaque_id),
      )
      expect(last_response).to have_json_body.that_includes(
        items: contain_exactly(include(connection_url: "postgres://***:***@foo.bar/spam")),
      )
    end

    it "returns a message if there are no targets" do
      get "/v1/organizations/#{org.key}/sync_targets"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: [],
        message: include("has no sync targets set up"),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/sync_targets/create" do
    it "creates the sync target for service integration" do
      post "/v1/organizations/#{org.key}/sync_targets/create",
           service_integration_opaque_id: sint.opaque_id,
           connection_url: "postgres://a.b"

      expect(last_response).to have_status(200)
      stgt = sint.sync_targets.first
      expect(stgt).to have_attributes(
        connection_url: "postgres://a.b",
        period_seconds: 43_500, # Midpoint between 10 minutes and 24 hours
        table: "",
        schema: "",
      )
    end

    it "can specify all fields" do
      post "/v1/organizations/#{org.key}/sync_targets/create",
           service_integration_opaque_id: sint.opaque_id,
           connection_url: "postgres://a.b",
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

    it "403s if service integration with given identifier doesn't exist" do
      post "/v1/organizations/#{org.key}/sync_targets/create",
           service_integration_opaque_id: "fakesint", connection_url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no service integration with that identifier."),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/sync_targets/create",
           service_integration_opaque_id: sint.opaque_id, connection_url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end

    it "400s if there is no adapter for the url" do
      post "/v1/organizations/#{org.key}/sync_targets/create",
           service_integration_opaque_id: sint.opaque_id,
           connection_url: "superdb://a.b",
           table: "mytbl",
           schema: "my_schema",
           period_seconds: 11.minutes.to_i

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: /The connection URL is not supported/),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/sync_targets/:opaque_id/update_credentials" do
    let(:sync_tgt) do
      Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
    end

    it "updates the username and password" do
      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/update_credentials",
           user: "user", password: "pass"

      expect(last_response).to have_status(200)
      expect(sync_tgt.refresh).to have_attributes(connection_url: "postgres://user:pass@pg/db")
    end

    it "403s if the sync target does not exist for that org" do
      st = Webhookdb::Fixtures.sync_target.create
      post "/v1/organizations/#{org.key}/sync_targets/#{st.opaque_id}/update_credentials",
           user: "user", password: "pass"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no sync target with that id."),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/update_credentials",
           user: "user", password: "pass"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/sync_targets/:opaque_id/update" do
    let(:sync_tgt) do
      Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
    end

    it "can modify period, schema, and table" do
      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/update",
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
      post "/v1/organizations/#{org.key}/sync_targets/#{st.opaque_id}/update", table: "tbl"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no sync target with that id."),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/update", table: "tbl"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/sync_targets/:opaque_id/delete" do
    let(:sync_tgt) do
      Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
    end

    it "deletes the sync target" do
      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/delete", confirm: " #{sync_tgt.table} \n"

      expect(last_response).to have_status(200)
      expect(Webhookdb::SyncTarget.all).to be_empty
    end

    it "422s if the table name is not given as the confirmation value" do
      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/delete"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(code: "prompt_required_params"),
      )

      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/delete", confirm: sync_tgt.table + "x"

      expect(last_response).to have_status(422)
      expect(last_response).to have_json_body.that_includes(
        error: include(code: "prompt_required_params"),
      )
    end

    it "403s if the sync target does not exist for that org" do
      st = Webhookdb::Fixtures.sync_target.create
      post "/v1/organizations/#{org.key}/sync_targets/#{st.opaque_id}/delete", confirm: " #{sync_tgt.table} \n"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no sync target with that id."),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/delete", confirm: " #{sync_tgt.table} \n"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/sync_targets/:opaque_id/sync" do
    let(:sync_tgt) do
      Webhookdb::Fixtures.sync_target(service_integration: sint).create(connection_url: "postgres://a:b@pg/db")
    end

    it "scheduled the sync job" do
      Timecop.freeze("2022-05-05T10:00:00Z") do
        sync_tgt.update(last_synced_at: 3.minutes.ago)
        expect(Webhookdb::Jobs::SyncTargetRunSync).to receive(:perform_at).
          with(Time.parse("2022-05-05T10:07:00Z"), sync_tgt.id)
        post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/sync"
        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.
          that_includes(message: "Sync has been scheduled. It should start at about 2022-05-05 10:07:00 +0000.")
      end
    end

    it "403s if the sync target does not exist for that org" do
      st = Webhookdb::Fixtures.sync_target.create
      post "/v1/organizations/#{org.key}/sync_targets/#{st.opaque_id}/sync"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no sync target with that id."),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/sync_targets/#{sync_tgt.opaque_id}/sync"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end
end
