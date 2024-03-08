# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IncreaseAppV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: "increase_app_v1",
      backfill_key: "accesstoken",
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
          output: match("to learn more"),
        )
      end
    end
  end

  describe "build_dependents" do
    it "creates contact and conversation integrations and enqueues backfill jobs" do
      svc.build_dependents

      expect(org.service_integrations).to include(
        sint,
        have_attributes(service_name: "increase_account_v1"),
        have_attributes(service_name: "increase_limit_v1"),
      )

      expect(Webhookdb::BackfillJob.all).to have_length(be > 5)
      expect(Webhookdb::BackfillJob.all).to all(be_incremental)
    end
  end
end
