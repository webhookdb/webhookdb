# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IntercomMarketplaceRootV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: "intercom_marketplace_root_v1",
      backfill_key: "intercom_auth_token",
      organization: org,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }

  it "can create its table in its org db" do
    sint.organization.prepare_database_connections
    svc.create_table
    svc.readonly_dataset do |ds|
      expect(ds.db).to be_table_exists(svc.qualified_table_sequel_identifier)
    end
    expect(sint.db).to_not be_table_exists(svc.qualified_table_sequel_identifier)
    sint.organization.remove_related_database
  end

  describe "backfill" do
    it "noops" do
      expect { backfill(sint) }.to_not raise_error
    end
  end

  describe "state machine calculation" do
    describe "calculate_backfill_state_machine" do
      it "noops" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("This integration cannot be modified through the command line"),
        )
      end
    end
  end

  describe "build_dependents" do
    it "creates contact and conversation integrations and enqueues backfill jobs" do
      svc.build_dependents

      contact_sint = Webhookdb::ServiceIntegration[
        service_name: "intercom_contact_v1",
        organization: org,
      ]
      conversation_sint = Webhookdb::ServiceIntegration[
        service_name: "intercom_conversation_v1",
        organization: org,
      ]

      expect(org.service_integrations).to contain_exactly(
        sint,
        contact_sint,
        conversation_sint,
      )

      expect(Webhookdb::BackfillJob).to contain_exactly(
        include(service_integration_id: contact_sint.id, incremental: true),
        include(service_integration_id: conversation_sint.id, incremental: true),
      )
    end
  end
end
