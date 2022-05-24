# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe "fake implementations", :db do
  describe Webhookdb::Services::Fake do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a service implementation", "fake_v1" do
      let(:body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "fake_v1" do
      let(:old_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
      let(:new_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2016 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation that can backfill", "fake_v1" do
      let(:page1_items) do
        [
          {"my_id" => "1", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
          {"my_id" => "2", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        ]
      end
      let(:page2_items) do
        [
          {"my_id" => "3", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
          {"my_id" => "4", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        ]
      end
      let(:expected_items_count) { 4 }
      def stub_service_requests
        return [
          stub_request(:get, "https://fake-integration/?token=").
              to_return(status: 200, body: [page1_items,
                                            "p2",].to_json, headers: {"Content-Type" => "application/json"},),
          stub_request(:get, "https://fake-integration/?token=p2").
              to_return(status: 200, body: [page2_items, nil].to_json, headers: {"Content-Type" => "application/json"}),
        ]
      end

      def stub_service_request_error
        stub_request(:get, "https://fake-integration/?token=").
          to_return(status: 500, body: "erm")
      end
    end

    it_behaves_like "a service implementation that upserts webhooks only under specific conditions", "fake_v1" do
      before(:each) do
        described_class.prepare_for_insert_hook = ->(_h) {}
      end

      let(:incorrect_webhook) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation with dependents", "fake_v1", "fake_dependent_v1" do
      let(:body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
      let(:expected_insert) do
        {data: body.to_json, my_id: "abc", at: Time.parse(body["at"])}
      end
      before(:each) do
        Webhookdb::Services::FakeDependent.reset
      end

      after(:each) do
        Webhookdb::Services::FakeDependent.reset
      end
    end
  end

  describe Webhookdb::Services::FakeWithEnrichments do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a service implementation that uses enrichments", "fake_with_enrichments_v1" do
      let(:enrichment_tables) { described_class.enrichment_tables }
      let(:body) { {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"} }

      def stub_service_request
        return stub_request(:get, "https://fake-integration/enrichment/abc").
            to_return(status: 200, body: {extra: "abc"}.to_json, headers: {"Content-Type" => "application/json"})
      end

      def stub_service_request_error
        return stub_request(:get, "https://fake-integration/enrichment/abc").
            to_return(status: 500, body: "gerd")
      end

      def assert_is_enriched(row)
        expect(row[:data]["enrichment"]).to eq({"extra" => "abc"})
      end

      def assert_enrichment_after_insert(db)
        expect(db[:fake_v1_enrichments].all).to have_length(1)
      end
    end
  end

  describe Webhookdb::Services::FakeDependent do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a service implementation dependent on another", "fake_dependent_v1", "fake_v1" do
      let(:no_dependencies_message) { "You don't have any Fake integrations yet. You can run:" }
    end
  end

  describe "base class functionality" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }
    let(:fake) { sint.service_instance }

    describe "verify_backfill_credentials" do
      before(:each) do
        fake.define_singleton_method(:_verify_backfill_408_err_msg) do
          "custom 408 message"
        end
        fake.define_singleton_method(:_verify_backfill_err_msg) do
          "default message"
        end
      end

      it "verifies on success" do
        Webhookdb::Services::Fake.stub_backfill_request([])
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: true, message: "")
      end

      it "uses a default error message" do
        Webhookdb::Services::Fake.stub_backfill_request([], status: 401)
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: false, message: "default message")
      end

      it "can use code-specific error messages" do
        Webhookdb::Services::Fake.stub_backfill_request([], status: 408)
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: false, message: "custom 408 message")
      end
    end

    describe "ensure_all_columns" do
      before(:each) do
        sint.organization.prepare_database_connections
      end

      after(:each) do
        sint.organization.remove_related_database
      end

      it "uses create_table SQL if the table does not exist" do
        expect(fake.ensure_all_columns_sql).to eq(fake.create_table_sql)
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.db).to be_table_exists(sint.table_name) }
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
      end

      it "returns empty string if all columns exist" do
        fake.create_table
        expect(fake.ensure_all_columns_sql).to eq("")
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
      end

      it "can build and execute SQL for columns that exist in code but not in the DB" do
        fake.create_table
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Services::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TIMESTAMP, index: true),
            Webhookdb::Services::Column.new(:c3, Webhookdb::DBAdapter::ColumnTypes::DATE),
            Webhookdb::Services::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
          ]
        end
        expect(fake.ensure_all_columns_sql).to eq(%{ALTER TABLE #{fake.table_sym} ADD c2 timestamptz;
CREATE INDEX IF NOT EXISTS c2_idx ON #{fake.table_sym} (c2);
ALTER TABLE #{fake.table_sym} ADD c3 date;
ALTER TABLE #{fake.table_sym} ADD "from" text;
CREATE INDEX IF NOT EXISTS from_idx ON #{fake.table_sym} ("from");})
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data, :c2, :c3, :from]) }
      end
    end

    describe "calculate_dependency_state_machine_step" do
      let(:org) { Webhookdb::Fixtures.organization.create }
      let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
      let(:sint) { fac.create(service_name: "fake_dependent_v1") }

      it "completes with an error when the org has no candidates for a dependency" do
        step = sint.service_instance.calculate_dependency_state_machine_step(dependency_help: "Explain the deps.")
        expect(step).to have_attributes(
          needs_input: false,
          complete: true,
          output: %(This integration requires Fakes to sync.

You don't have any Fake integrations yet. You can run:

  webhookdb integrations create fake_v1

to set one up. Then once that's complete, you can re-run:

  webhookdb integrations create fake_dependent_v1

to keep going.
),
          error_code: "no_candidate_dependency",
        )
      end

      it "prompts when the org has candidates for a dependency" do
        candidates = Array.new(2) { fac.create(service_name: "fake_v1") }
        step = sint.service_instance.calculate_dependency_state_machine_step(dependency_help: "Explain the deps.")
        expect(step).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your Parent integration number here:",
          prompt_is_secret: false,
          post_to_url: end_with("/transition/dependency_choice"),
          output: %(This integration requires Fakes to sync.

Explain the deps.

Enter the number for the Fake integration you want to use,
or leave blank to choose the first option.

1 - #{candidates[0].table_name}
2 - #{candidates[1].table_name}
),
          post_params_value_key: "value",
        )
      end

      it "returns nil if a dependency exists" do
        sint.update(depends_on: fac.create(service_name: "fake_v1"))
        expect(sint.service_instance.calculate_dependency_state_machine_step(dependency_help: "")).to be_nil
      end

      it "raises if the service does not use dependencies" do
        sint = fac.create(service_name: "fake_v1")
        expect do
          sint.service_instance.calculate_dependency_state_machine_step(dependency_help: "")
        end.to raise_error(Webhookdb::InvalidPrecondition)
      end
    end

    describe "process_state_change" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create }

      it "sets and returns the create state machine for relevant fields" do
        step = sint.service_instance.process_state_change("webhook_secret", "abcd")
        expect(step).to have_attributes(output: include("The integration creation flow is working correctly"))
        expect(sint).to have_attributes(webhook_secret: "abcd")
      end

      it "returns the backfill state machine for relevant fields" do
        step = sint.service_instance.process_state_change("backfill_secret", "abcd")
        expect(step).to have_attributes(output: include("The backfill flow is working correctly"))
        expect(sint).to have_attributes(backfill_secret: "abcd")
      end

      it "raises error for unhandled fields" do
        expect do
          sint.service_instance.process_state_change("updated_at", Time.now)
        end.to raise_error(ArgumentError)
      end

      describe "setting dependency_choice" do
        let(:org) { Webhookdb::Fixtures.organization.create }
        let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
        let!(:dependent) { fac.create(service_name: "fake_dependent_v1") }
        let!(:dependency1) { fac.create(service_name: "fake_v1") }
        let!(:dependency2) { fac.create(service_name: "fake_v1") }

        it "sets depends_on to the specified dependency" do
          step = dependent.service_instance.process_state_change("dependency_choice", "2")
          expect(step).to have_attributes(output: include("You're creating a fake_v1 service integration"))
          expect(dependent).to have_attributes(depends_on: be === dependency2)
        end

        it "uses the first dependency if blank" do
          step = dependent.service_instance.process_state_change("dependency_choice", " ")
          expect(step).to have_attributes(output: include("You're creating a fake_v1 service integration"))
          expect(dependent).to have_attributes(depends_on: be === dependency1)
        end

        it "errors if the value is invalid or has no dependencies" do
          expect do
            sint.service_instance.process_state_change("dependency_choice", "3")
          end.to raise_error(Webhookdb::InvalidPrecondition)
          expect do
            dependent.service_instance.process_state_change("dependency_choice", "3")
          end.to raise_error(Webhookdb::InvalidInput)
          expect do
            dependent.service_instance.process_state_change("dependency_choice", "abc")
          end.to raise_error(Webhookdb::InvalidInput)
        end
      end
    end

    describe "webhook_response" do
      it "defers to the protected method" do
        Webhookdb::Services::Fake.webhook_response = Webhookdb::WebhookResponse.error("hi")
        expect(fake.webhook_response(nil)).to have_attributes(status: 401, reason: "hi")
      end

      it "can override verification" do
        Webhookdb::Services::Fake.webhook_response = Webhookdb::WebhookResponse.error("hi")
        expect(fake.webhook_response(nil)).to have_attributes(status: 401, reason: "hi")
        sint.skip_webhook_verification = true
        expect(fake.webhook_response(nil)).to have_attributes(status: 201)
      end
    end
  end
end
