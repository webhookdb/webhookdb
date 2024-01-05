# frozen_string_literal: true

require "webhookdb/api/demo"

RSpec.describe Webhookdb::API::Demo, :db, reset_configuration: Webhookdb::DemoMode do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  describe "POST /v1/demo/data" do
    describe "with the demo server mode disabled" do
      before(:each) do
        Webhookdb::DemoMode.demo_org_id = 0
      end

      it "errors with a 403" do
        post "/v1/demo/data"

        expect(last_response).to have_status(403)
      end
    end

    describe "with the demo server mode enabled" do
      let(:demo_org) { Webhookdb::Fixtures.organization.create }
      let(:sint_fac) { Webhookdb::Fixtures.service_integration(organization: demo_org) }
      let(:gh_pulls) { sint_fac.create(service_name: "github_pull_v1") }

      before(:each) do
        Webhookdb::DemoMode.demo_org_id = demo_org.id
        demo_org.prepare_database_connections
        gh_pulls.replicator.create_table
      end

      after(:each) do
        demo_org.remove_related_database
      end

      it "returns data from demo integrations" do
        gh_pulls.replicator.upsert_webhook_body(
          {id: 2, node_id: "x", number: 1, state: "open", created_at: nil, updated_at: nil, closed_at: nil}.as_json,
        )

        post "/v1/demo/data"

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(
          data: [
            {
              service_name: "github_pull_v1",
              rows_data: [
                {
                  id: 2,
                  state: "open",
                  number: 1,
                  node_id: "x",
                  closed_at: nil,
                  created_at: nil,
                  updated_at: nil,
                },
              ],
            },
          ],
        )
      end
    end
  end
end
