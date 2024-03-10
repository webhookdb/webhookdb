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
    it "creates all dependent replicators and enqueues backfill jobs" do
      svc.build_dependents

      expect(org.service_integrations).to include(
        sint,
        have_attributes(service_name: "increase_account_v1"),
        have_attributes(service_name: "increase_wire_transfer_v1"),
      )
      expect(org.service_integrations).to_not include(have_attributes(service_name: "increase_limit_v1"))

      expect(Webhookdb::BackfillJob.all).to have_length(be > 5)
      expect(Webhookdb::BackfillJob.all).to all(have_attributes(incremental: false))
    end

    it "creates the limit replicator if the account has that role" do
      org.add_feature_role Webhookdb::Role.create(name: "increase_limits")

      svc.build_dependents

      expect(org.service_integrations).to include(have_attributes(service_name: "increase_limit_v1"))
    end
  end

  describe "upsert_webhook behavior" do
    let(:event_body) do
      {
        associated_object_id: "account_in71c4amph0vgo2qllky",
        associated_object_type: "account",
        category: "account.created",
        created_at: "2020-01-31T23:59:59Z",
        id: "event_001dzz0r20rzr4zrhrr1364hy80",
        type: "event",
      }.as_json
    end

    it "dispatches the event to the event replicator and all replicators matching the event associated object type" do
      acct = {
        bank: "first_internet_bank",
        created_at: "2020-01-31T23:59:59Z",
        currency: "USD",
        entity_id: "entity_n8y8tnk2p9339ti393yi",
        id: "account_in71c4amph0vgo2qllky",
        interest_accrued: "0.01",
        name: "My first account!",
        status: "open",
        type: "account",
      }
      req = stub_request(:get, "https://api.increase.com/accounts/account_in71c4amph0vgo2qllky").
        with(headers: {"Authorization" => "Bearer accesstoken"}).
        to_return(json_response(acct), json_response(acct))

      org.prepare_database_connections
      fac = Webhookdb::Fixtures.service_integration(organization: org)
      event = fac.create(service_name: "increase_event_v1", depends_on: sint)
      dep1 = fac.create(service_name: "increase_account_v1", depends_on: sint)
      dep2 = fac.create(service_name: "increase_account_v1", depends_on: sint)
      org.service_integrations.each { |sint| sint.replicator.create_table }

      expect(svc.upsert_webhook_body(event_body)).to be_nil
      expect(event.replicator.admin_dataset(&:all)).to contain_exactly(
        include(increase_id: "event_001dzz0r20rzr4zrhrr1364hy80"),
      )
      expect(dep1.replicator.admin_dataset(&:all)).to contain_exactly(
        include(increase_id: "account_in71c4amph0vgo2qllky"),
      )
      expect(dep2.replicator.admin_dataset(&:all)).to contain_exactly(
        include(increase_id: "account_in71c4amph0vgo2qllky"),
      )
      expect(req).to have_been_made.times(2)
    ensure
      org.remove_related_database
    end

    it "errors if the request body is not an event" do
      event_body["type"] = "event2"

      expect { svc.upsert_webhook_body(event_body) }.to raise_error(Webhookdb::InvalidPrecondition)
    end
  end
end
