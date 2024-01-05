# frozen_string_literal: true

require "webhookdb/demo_mode"

RSpec.describe Webhookdb::DemoMode, :db, reset_configuration: Webhookdb::DemoMode do
  describe "build_demo_data" do
    let(:demo_org) { Webhookdb::Fixtures.organization.create }
    let(:sint_fac) { Webhookdb::Fixtures.service_integration(organization: demo_org) }
    let(:fake_sint) { sint_fac.create(service_name: "fake_v1") }
    let(:gh_issues) { sint_fac.create(service_name: "github_issue_v1") }
    let(:gh_pulls) { sint_fac.create(service_name: "github_pull_v1") }

    before(:each) do
      demo_org.prepare_database_connections
      [fake_sint, gh_issues, gh_pulls].each { |r| r.replicator.create_table }
    end

    after(:each) do
      demo_org.remove_related_database
    end

    it "raises if server demo mode is not enabled" do
      expect { described_class.build_demo_data }.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "returns demo service integrations" do
      described_class.demo_org_id = demo_org.id
      gh_pulls.replicator.upsert_webhook_body(
        {id: 2, node_id: "x", number: 1, state: "open", created_at: nil, updated_at: nil, closed_at: nil}.as_json,
      )
      expect(described_class.build_demo_data.as_json.deep_symbolize_keys).to eq(
        {
          data: [
            {
              service_name: "github_issue_v1",
              rows_data: [],
            },
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
        },
      )
    end
  end

  describe "handle_auth" do
    it "raises if client demo mode is not enabled" do
      expect { described_class.handle_auth }.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "creates/returns a customer for the configured demo email" do
      described_class.client_enabled = true

      membership, step, msg = described_class.handle_auth
      expect(membership.customer).to have_attributes(email: "demo@webhookdb.com")
      expect(step).to have_attributes(complete: true)
      expect(msg).to include("demo version of WebhookDB")

      membership2, _, _ = described_class.handle_auth
      expect(membership).to be === membership2
    end

    it "triggers a sync job", :async, :do_not_defer_events do
      described_class.client_enabled = true
      expect do
        described_class.handle_auth
      end.to publish("webhookdb.organization.syncdemodata").with_payload(contain_exactly(be_a(Integer)))
    end
  end

  describe "sync_demo_data" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:demo_data) do
      {data: [
        {
          service_name: "github_issue_v1",
          rows_data: [],
        },
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
            {
              id: 20,
              state: "open",
              number: 10,
              node_id: "y",
              closed_at: nil,
              created_at: nil,
              updated_at: nil,
            },
          ],
        },
      ]}
    end

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "returns false if client demo mode is not enabled" do
      expect(described_class.sync_demo_data(org)).to be(false)
    end

    it "creates service integrations and tables with data for the demo customer org" do
      req = stub_request(:post, "https://api.webhookdb.com/v1/demo/data").
        to_return(json_response(demo_data))

      described_class.client_enabled = true
      described_class.sync_demo_data(org)
      expect(req).to have_been_made
      org.refresh
      expect(org.service_integrations).to have_length(2)
      issues = org.service_integrations_dataset[service_name: "github_issue_v1"]
      expect(issues).to have_attributes(table_name: "github_issue_v1_demo")
      expect(issues.replicator.admin_dataset(&:all)).to be_empty
      pulls = org.service_integrations_dataset[service_name: "github_pull_v1"]
      expect(pulls).to have_attributes(table_name: "github_pull_v1_demo")
      expect(pulls.replicator.admin_dataset { |ds| ds.select_map([:node_id, :number]) }).to eq([["x", 1], ["y", 10]])
    end

    it "runs idempotently" do
      req = stub_request(:post, "https://api.webhookdb.com/v1/demo/data").
        to_return(json_response(demo_data), json_response(demo_data))

      described_class.client_enabled = true
      described_class.sync_demo_data(org)
      org.refresh
      expect(org.service_integrations).to have_length(2)
      described_class.sync_demo_data(org)
      expect(req).to have_been_made.twice
      org.refresh
      expect(org.service_integrations).to have_length(2)
    end
  end
end
