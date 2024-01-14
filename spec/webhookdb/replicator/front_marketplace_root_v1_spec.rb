# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::FrontMarketplaceRootV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: "front_marketplace_root_v1",
      api_url: "front_lithic_test.api.frontapp.com",
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

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "tells the user to set up the integration through the app store" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: match("Front integrations can only be enabled through the Front App Store"),
        )
      end
    end
  end
end
