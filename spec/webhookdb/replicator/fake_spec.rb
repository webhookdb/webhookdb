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
        described_class.resource_and_event_hook = ->(_h) {}
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

    it "emits the backfill event for dependents when cascade is true", :async, :do_not_defer_events do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1", backfill_key: "abc123")
      svc = Webhookdb::Services.service_instance(sint)
      dependent_sint = Webhookdb::Fixtures.service_integration.depending_on(sint).create(
        service_name: "fake_dependent_v1",
        organization: sint.organization,
      )
      dependent_svc = Webhookdb::Services.service_instance(dependent_sint)
      sint.organization.prepare_database_connections
      svc.create_table
      dependent_svc.create_table

      page_items = [
        {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        {"my_id" => "def", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
      ]
      backfill_req = stub_request(:get, "https://fake-integration/?token=").
        to_return(
          status: 200,
          body: [page_items, nil].to_json,
          headers: {"Content-Type" => "application/json"},
        )

      expect do
        svc.backfill(cascade: true)
      end.to publish("webhookdb.serviceintegration.backfill").
        with_payload([dependent_sint.id, {"cascade" => true, "incremental" => false}])
      expect(backfill_req).to have_been_made
    end

    it "stops backfill pagination if regression mode is set", :regression_mode do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1", backfill_key: "abc123")
      sint.organization.prepare_database_connections
      sint.service_instance.create_table

      page_items = [
        {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        {"my_id" => "def", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
      ]
      req = stub_request(:get, "https://fake-integration/?token=").
        to_return(
          status: 200,
          # Returning the pagination token here would normally cause another request to be made
          body: [page_items, "tok1"].to_json,
          headers: {"Content-Type" => "application/json"},
        )

      sint.service_instance.backfill
      expect(req).to have_been_made
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
      let(:body) { {"my_id" => "abc", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"} }
      let(:enrichment_body) { {extra: "abc"}.to_json }
      let(:expected_enrichment_data) { JSON.parse(enrichment_body) }

      def stub_service_request
        return stub_request(:get, "https://fake-integration/enrichment/abc").
            to_return(status: 200, body: enrichment_body, headers: {"Content-Type" => "application/json"})
      end

      def stub_service_request_error
        return stub_request(:get, "https://fake-integration/enrichment/abc").
            to_return(status: 500, body: "gerd")
      end

      def assert_is_enriched(row)
        expect(row[:extra]).to eq("abc")
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

  describe Webhookdb::Services::FakeDependentDependent do
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
        Webhookdb::Services::Fake.reset
      end

      it "uses create_table modification if the table does not exist" do
        expect(fake.ensure_all_columns_modification.to_s).to eq(fake.create_table_modification.to_s)
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.db).to be_table_exists(sint.table_name) }
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
      end

      it "returns empty string if all columns exist" do
        fake.create_table
        expect(fake.ensure_all_columns_modification.to_s).to eq("")
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
      end

      it "can build and execute SQL for columns that exist in code but not in the DB" do
        fake.service_integration.opaque_id = "svi_xyz"
        fake.create_table
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data]) }
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Services::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TIMESTAMP, index: true),
            Webhookdb::Services::Column.new(:c3, Webhookdb::DBAdapter::ColumnTypes::DATE),
            Webhookdb::Services::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
          ]
        end
        table_str = fake.schema_and_table_symbols.map(&:to_s).join(".")
        expect(fake.ensure_all_columns_modification.to_s).to include(
          %(ALTER TABLE #{table_str} ADD COLUMN c2 timestamptz;
ALTER TABLE #{table_str} ADD COLUMN c3 date;
ALTER TABLE #{table_str} ADD COLUMN "from" text;),
        )
        expect(fake.ensure_all_columns_modification.to_s).to include(
          %{CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_xyz_c2_idx ON #{table_str} (c2);
CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_xyz_from_idx ON #{table_str} ("from");},
        )
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data, :c2, :c3, :from]) }
      end

      it "can build and execute SQL for indices that exist in code but not in the DB" do
        fake.service_integration.update(opaque_id: "svi_abc", table_name: "xtbl")
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Services::Column.new(:c1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Services::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TEXT),
          ]
        end
        fake.create_table
        fake.readonly_dataset do |ds|
          indices = ds.db[:pg_indexes].where(tablename: "xtbl").select_map(:indexname)
          expect(indices).to contain_exactly("svi_abc_c1_idx", "xtbl_my_id_key", "xtbl_pkey")
        end
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Services::Column.new(:c1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Services::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
          ]
        end
        expect(fake.ensure_all_columns_modification.to_s).to eq(
          "CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_abc_c2_idx ON public.xtbl (c2);",
        )
        fake.ensure_all_columns
        fake.readonly_dataset do |ds|
          indices = ds.db[:pg_indexes].where(tablename: "xtbl").select_map(:indexname)
          expect(indices).to contain_exactly("svi_abc_c2_idx", "svi_abc_c1_idx", "xtbl_my_id_key", "xtbl_pkey")
        end
      end

      it "can backfill values for columns that exist in code but not in the DB" do
        fake.create_table
        fake.admin_dataset do |ds|
          expect(ds.columns).to eq([:pk, :my_id, :at, :data])
          ds.insert(
            my_id: "abc123",
            at: Time.now,
            data: {
              c2: 14,
              from: "Canada",
            }.to_json,
          )
        end

        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Services::Column.new(
              :c2,
              Webhookdb::DBAdapter::ColumnTypes::INTEGER,
              converter: Webhookdb::Services::Column::CONV_TO_I,
            ),
            Webhookdb::Services::Column.new(:c3, Webhookdb::DBAdapter::ColumnTypes::TIMESTAMP, defaulter: :now),
            Webhookdb::Services::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
          ]
        end
        table_str = fake.schema_and_table_symbols.map(&:to_s).join('"."')
        expect(fake.ensure_all_columns_modification.to_s).to include(
          %{"c2" = CAST(CAST(("data" #> ARRAY['c2']) AS integer) AS integer)},
        )
        expect(fake.ensure_all_columns_modification.to_s).to include(
          %{"c3" = coalesce(CAST(("data" ->> 'c3') AS timestamptz), now())},
        )
        expect(fake.ensure_all_columns_modification.to_s).to include(%{"from" = CAST(("data" ->> 'from') AS text)})
        fake.ensure_all_columns
        fake.readonly_dataset do |ds|
          expect(ds.columns).to eq([:pk, :my_id, :at, :data, :c2, :c3, :from])
          expect(ds.first).to include({c2: 14, from: "Canada", my_id: "abc123", at: be_within(5.seconds).of(Time.now)})
        end
      end

      it "handles sequences during create" do
        expect(fake.create_table_modification.application_database_statements).to be_empty
        fake.class.requires_sequence = true
        expect(fake.create_table_modification.application_database_statements).to contain_exactly(
          /CREATE SEQUENCE IF NOT EXISTS replicator_seq_org_/,
        )
      end

      it "handles sequences during modification" do
        expect(fake.ensure_all_columns_modification.application_database_statements).to be_empty
        fake.class.requires_sequence = true
        expect(fake.ensure_all_columns_modification.application_database_statements).to contain_exactly(
          /CREATE SEQUENCE IF NOT EXISTS replicator_seq_org_/,
        )
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
