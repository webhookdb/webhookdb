# frozen_string_literal: true

require "support/shared_examples_for_replicators"

# rubocop:disable Layout/LineLength

RSpec.describe "fake implementations", :db do
  describe Webhookdb::Replicator::Fake do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a replicator" do
      let(:body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a replicator that prevents overwriting new data with old" do
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

    it_behaves_like "a replicator that can backfill" do
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
              to_return(status: 200, body: [page1_items, "p2"].to_json, headers: json_headers),
          stub_request(:get, "https://fake-integration/?token=p2").
              to_return(status: 200, body: [page2_items, nil].to_json, headers: json_headers),
        ]
      end

      def stub_empty_requests
        return [
          stub_request(:get, "https://fake-integration/?token=").
              to_return(status: 200, body: [[], nil].to_json, headers: json_headers),
        ]
      end

      def stub_service_request_error
        stub_request(:get, "https://fake-integration/?token=").
          to_return(status: 400, body: "erm")
      end
    end

    it_behaves_like "a replicator that upserts webhooks only under specific conditions" do
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

    it_behaves_like "a replicator with dependents", "fake_dependent_v1" do
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
        Webhookdb::Replicator::FakeDependent.reset
      end

      after(:each) do
        Webhookdb::Replicator::FakeDependent.reset
      end
    end

    it "emits the backfill event for dependents when cascade is true", :async, :do_not_defer_events do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1", backfill_key: "abc123")
      svc = Webhookdb::Replicator.create(sint)
      dependent_sint = Webhookdb::Fixtures.service_integration.depending_on(sint).create(
        service_name: "fake_dependent_v1",
        organization: sint.organization,
      )
      dependent_svc = Webhookdb::Replicator.create(dependent_sint)
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

      bfjob = Webhookdb::Fixtures.backfill_job.for(sint).cascade.create
      expect do
        svc.backfill(bfjob)
      end.to publish("webhookdb.backfilljob.run").with_payload([bfjob.child_jobs.first.id])
      expect(backfill_req).to have_been_made
    end

    it "stops backfill pagination if regression mode is set", :regression_mode do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1", backfill_key: "abc123")
      sint.organization.prepare_database_connections
      sint.replicator.create_table

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

      backfill(sint)
      expect(req).to have_been_made
    end
  end

  describe Webhookdb::Replicator::FakeWithEnrichments do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a replicator that uses enrichments" do
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

  describe Webhookdb::Replicator::FakeDependent do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a replicator dependent on another", "fake_v1" do
      let(:no_dependencies_message) { "You don't have any Fake integrations yet. You can run:" }
    end
  end

  describe Webhookdb::Replicator::FakeDependentDependent do
    before(:each) do
      described_class.reset
    end

    after(:each) do
      described_class.reset
    end

    it_behaves_like "a replicator dependent on another", "fake_dependent_v1" do
      let(:no_dependencies_message) { "You don't have any FakeDependent integrations yet. You can run:" }
    end
  end

  describe "base class functionality" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }
    let(:fake) { sint.replicator }

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
        Webhookdb::Replicator::Fake.stub_backfill_request([])
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: true, message: "")
      end

      it "uses a default error message" do
        Webhookdb::Replicator::Fake.stub_backfill_request([], status: 401)
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: false, message: "default message")
      end

      it "can use code-specific error messages" do
        Webhookdb::Replicator::Fake.stub_backfill_request([], status: 408)
        result = fake.verify_backfill_credentials
        expect(result).to have_attributes(verified: false, message: "custom 408 message")
      end
    end

    describe "ensure_all_columns", :fake_replicator do
      before(:each) do
        sint.organization.prepare_database_connections
      end

      after(:each) do
        sint.organization.remove_related_database
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

      it "can build and execute SQL for columns and indices that exist in code but not in the DB" do
        fake.service_integration.opaque_id = "svi_xyz"
        orig_cols = fake._denormalized_columns + [
          Webhookdb::Replicator::Column.new(:bf1,
                                            Webhookdb::DBAdapter::ColumnTypes::INTEGER_ARRAY,
                                            backfill_expr: Sequel.lit("never see me"),),
        ]
        fake.define_singleton_method(:_denormalized_columns) do
          orig_cols
        end

        table_str = fake.schema_and_table_symbols.map(&:to_s).join(".")
        fqtable_str = '"' + fake.schema_and_table_symbols.map(&:to_s).join('"."') + '"'
        fake.define_singleton_method(:_extra_index_specs) do
          [Webhookdb::Replicator::IndexSpec.new(columns: [:my_id, :at])]
        end

        expect(fake.ensure_all_columns_modification.to_s.strip).to eq(<<~SQL.strip)
          CREATE TABLE #{table_str} (
            pk bigserial PRIMARY KEY,
            my_id text UNIQUE NOT NULL,
            at timestamptz,
            bf1 integer[],
            data jsonb NOT NULL
          );
          CREATE INDEX IF NOT EXISTS svi_xyz_at_idx ON #{table_str} (at);
          CREATE INDEX IF NOT EXISTS svi_xyz_my_id_at_idx ON #{table_str} (my_id, at);
        SQL

        fake.create_table
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :bf1, :data]) }
        fake.define_singleton_method(:_denormalized_columns) do
          orig_cols + [
            Webhookdb::Replicator::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TIMESTAMP, index: true),
            Webhookdb::Replicator::Column.new(:c3, Webhookdb::DBAdapter::ColumnTypes::DATE),
            Webhookdb::Replicator::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Replicator::Column.new(
              :bf2,
              Webhookdb::DBAdapter::ColumnTypes::INTEGER_ARRAY,
              backfill_statement: Sequel.lit("CREATE OR REPLACE FUNCTION pg_temp.faketest_mapper(integer[])\n" \
                                             "RETURNS integer[] AS 'SELECT ARRAY(SELECT (n * 2) FROM unnest($1) AS n)' LANGUAGE sql IMMUTABLE"),
              backfill_expr: Sequel.lit("pg_temp.faketest_mapper(bf1)"),
            ),
          ]
        end
        fake.define_singleton_method(:_extra_index_specs) do
          [Webhookdb::Replicator::IndexSpec.new(columns: [:c2, :at])]
        end

        mod_sql = fake.ensure_all_columns_modification.to_s.strip
        expect(mod_sql).to include(<<~SQL.strip)
          ALTER TABLE #{table_str} ADD COLUMN c2 timestamptz;
          ALTER TABLE #{table_str} ADD COLUMN c3 date;
          ALTER TABLE #{table_str} ADD COLUMN "from" text;
          ALTER TABLE #{table_str} ADD COLUMN bf2 integer[];
          CREATE OR REPLACE FUNCTION pg_temp.faketest_mapper(integer[])
          RETURNS integer[] AS 'SELECT ARRAY(SELECT (n * 2) FROM unnest($1) AS n)' LANGUAGE sql IMMUTABLE;
        SQL
        expect(mod_sql).to include(<<~SQL.strip)
          CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_xyz_c2_idx ON #{table_str} (c2);
          CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_xyz_from_idx ON #{table_str} ("from");
          CREATE INDEX CONCURRENTLY IF NOT EXISTS svi_xyz_c2_at_idx ON #{table_str} (c2, at);
        SQL
        expect(mod_sql).to include(<<~SQL.strip)
          UPDATE #{fqtable_str} SET "c2" = CAST(("data" ->> 'c2') AS timestamptz), "c3" = CAST(("data" ->> 'c3') AS date), "from" = CAST(("data" ->> 'from') AS text), "bf2" = pg_temp.faketest_mapper(bf1) WHERE ("pk" > 0);
        SQL
        fake.ensure_all_columns
        fake.readonly_dataset do |ds|
          expect(ds.columns).to eq([:pk, :my_id, :at, :bf1, :data, :c2, :c3, :from, :bf2])
        end
      end

      it "backfills new columns with chunked UPDATE statements" do
        fake.service_integration.table_name = "faketbl"
        fake.create_table

        # Add a column that we'll backfill
        orig_cols = fake._denormalized_columns
        fake.define_singleton_method(:_denormalized_columns) do
          orig_cols + [Webhookdb::Replicator::Column.new(:tcol, Webhookdb::DBAdapter::ColumnTypes::TEXT)]
        end

        fake.admin_dataset do |ds|
          # Pretend we've inserted plenty of rows already.
          ds.db.execute "SELECT setval('#{fake.service_integration.table_name}_pk_seq', 3_000_001, true)"
          # Now insert an actual row, which will get a higher PK now
          ds.insert({my_id: "1", data: "{}"})
        end

        # Ensure the UPDATEs are done in chunks
        mod_sql = fake.ensure_all_columns_modification.to_s.strip
        expect(mod_sql).to eq(<<~SQL.strip)
          ALTER TABLE public.faketbl ADD COLUMN tcol text;
          UPDATE "public"."faketbl" SET "tcol" = CAST(("data" ->> 'tcol') AS text) WHERE (("pk" > 0) AND ("pk" <= 1000000));
          UPDATE "public"."faketbl" SET "tcol" = CAST(("data" ->> 'tcol') AS text) WHERE (("pk" > 1000000) AND ("pk" <= 2000000));
          UPDATE "public"."faketbl" SET "tcol" = CAST(("data" ->> 'tcol') AS text) WHERE (("pk" > 2000000) AND ("pk" <= 3000000));
          UPDATE "public"."faketbl" SET "tcol" = CAST(("data" ->> 'tcol') AS text) WHERE ("pk" > 3000000);
        SQL
        fake.ensure_all_columns
        fake.readonly_dataset do |ds|
          expect(ds.columns).to eq([:pk, :my_id, :at, :data, :tcol])
        end
      end

      it "chunks rows for update properly" do
        chunks = ->(n) { Webhookdb::Replicator::Fake.chunked_row_update_bounds(n) }
        expect(chunks.call(0)).to eq([[0]])
        expect(chunks.call(1)).to eq([[0]])
        expect(chunks.call(999_999)).to eq([[0]])
        expect(chunks.call(1_000_000)).to eq([[0, 1_000_000], [1_000_000]])
        expect(chunks.call(1_000_001)).to eq([[0, 1_000_000], [1_000_000]])
        expect(chunks.call(1_999_999)).to eq([[0, 1_000_000], [1_000_000]])
        expect(chunks.call(2_000_000)).to eq([[0, 1_000_000], [1_000_000, 2_000_000], [2_000_000]])
        expect(chunks.call(2_000_001)).to eq([[0, 1_000_000], [1_000_000, 2_000_000], [2_000_000]])
      end

      it "can build and execute SQL for indices that exist in code but not in the DB" do
        fake.service_integration.update(opaque_id: "svi_abc", table_name: "xtbl")
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Replicator::Column.new(:c1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Replicator::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TEXT),
          ]
        end
        fake.create_table
        fake.readonly_dataset do |ds|
          indices = ds.db[:pg_indexes].where(tablename: "xtbl").select_map(:indexname)
          expect(indices).to contain_exactly("svi_abc_c1_idx", "xtbl_my_id_key", "xtbl_pkey")
        end
        fake.define_singleton_method(:_denormalized_columns) do
          [
            Webhookdb::Replicator::Column.new(:c1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Replicator::Column.new(:c2, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
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

      it "handles legacy opaque ids starting with numbers" do
        fake.service_integration.update(opaque_id: "012abc", table_name: "xtbl")
        fake.define_singleton_method(:_denormalized_columns) do
          [Webhookdb::Replicator::Column.new(:c1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true)]
        end
        fake.create_table
        fake.readonly_dataset do |ds|
          indices = ds.db[:pg_indexes].where(tablename: "xtbl").select_map(:indexname)
          expect(indices).to contain_exactly("idx012abc_c1_idx", "xtbl_my_id_key", "xtbl_pkey")
        end
      end

      it "can use more index options,such as :where" do
        fake.service_integration.opaque_id = "svi_xyz"
        fake.define_singleton_method(:_extra_index_specs) do
          [
            Webhookdb::Replicator::IndexSpec.new(columns: [:my_id], where: Sequel[:at] > nil),
            Webhookdb::Replicator::IndexSpec.new(columns: [:my_id], where: Sequel[:at].is_distinct_from(nil)),
          ]
        end
        table_str = fake.schema_and_table_symbols.map(&:to_s).join(".")

        expect(fake.ensure_all_columns_modification.to_s.strip).to eq(<<~SQL.strip)
          CREATE TABLE #{table_str} (
            pk bigserial PRIMARY KEY,
            my_id text UNIQUE NOT NULL,
            at timestamptz,
            data jsonb NOT NULL
          );
          CREATE INDEX IF NOT EXISTS svi_xyz_at_idx ON #{table_str} (at);
          CREATE INDEX IF NOT EXISTS svi_xyz_my_id_idx ON #{table_str} (my_id) WHERE ("at" > NULL);
          CREATE INDEX IF NOT EXISTS svi_xyz_my_id_idx ON #{table_str} (my_id) WHERE ("at" IS DISTINCT FROM NULL);
        SQL

        fake.create_table
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
            Webhookdb::Replicator::Column.new(
              :c2,
              Webhookdb::DBAdapter::ColumnTypes::INTEGER,
              converter: Webhookdb::Replicator::Column::CONV_TO_I,
            ),
            Webhookdb::Replicator::Column.new(:c3, Webhookdb::DBAdapter::ColumnTypes::TIMESTAMP, defaulter: :now),
            Webhookdb::Replicator::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
          ]
        end
        expect(fake.ensure_all_columns_modification.to_s).to include(
          %{"c2" = CAST(CAST(("data" ->> 'c2') AS integer) AS integer)},
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
        step = sint.replicator.calculate_dependency_state_machine_step(dependency_help: "Explain the deps.")
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
        step = sint.replicator.calculate_dependency_state_machine_step(dependency_help: "Explain the deps.")
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
        expect(sint.replicator.calculate_dependency_state_machine_step(dependency_help: "")).to be_nil
      end

      it "raises if the service does not use dependencies" do
        sint = fac.create(service_name: "fake_v1")
        expect do
          sint.replicator.calculate_dependency_state_machine_step(dependency_help: "")
        end.to raise_error(Webhookdb::InvalidPrecondition)
      end
    end

    describe "process_state_change" do
      it "sets and returns the webhook state machine for relevant fields" do
        sint = Webhookdb::Fixtures.service_integration.create
        step = sint.replicator.process_state_change("webhook_secret", "abcd")
        expect(step).to have_attributes(output: include("The integration creation flow is working correctly"))
        expect(sint).to have_attributes(webhook_secret: "abcd")
        expect(Webhookdb::BackfillJob.all).to be_empty
      end

      it "can use the backfill state machine for webhook fields if webhooks are unsupported" do
        sint = Webhookdb::Fixtures.service_integration.
          create(backfill_secret: "x", service_name: "fake_backfill_only_v1")
        step = sint.replicator.process_state_change("webhook_secret", "abcd")
        expect(step).to have_attributes(output: include("The backfill flow is working correctly"))
        expect(sint).to have_attributes(webhook_secret: "abcd")
        expect(Webhookdb::BackfillJob.all).to have_length(1)
      end

      it "returns the backfill state machine for relevant fields" do
        sint = Webhookdb::Fixtures.service_integration.create
        step = sint.replicator.process_state_change("backfill_secret", "abcd")
        expect(step).to have_attributes(output: include("The backfill flow is working correctly"))
        expect(sint).to have_attributes(backfill_secret: "abcd")
        expect(Webhookdb::BackfillJob.all).to have_length(1)
      end

      it "can use the webhook state machine for backfill fields if backfilling is not supported" do
        sint = Webhookdb::Fixtures.service_integration.
          create(webhook_secret: "x", service_name: "fake_webhooks_only_v1")
        step = sint.replicator.process_state_change("backfill_secret", "abcd")
        expect(step).to have_attributes(output: include("The integration creation flow is working correctly"))
        expect(sint).to have_attributes(backfill_secret: "abcd")
        expect(Webhookdb::BackfillJob.all).to be_empty
      end

      it "raises error for unhandled fields" do
        sint = Webhookdb::Fixtures.service_integration.create
        expect do
          sint.replicator.process_state_change("updated_at", Time.now)
        end.to raise_error(ArgumentError)
      end

      it "always strips whitespace from the value" do
        sint = Webhookdb::Fixtures.service_integration.create
        sint.replicator.process_state_change("backfill_secret", " ab cd ")
        sint.replicator.process_state_change("webhook_secret", "\nxy zw\n")
        expect(sint).to have_attributes(backfill_secret: "ab cd", webhook_secret: "xy zw")
      end

      describe "setting dependency_choice" do
        let(:org) { Webhookdb::Fixtures.organization.create }
        let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
        let!(:dependent) { fac.create(service_name: "fake_dependent_v1") }
        let!(:dependency1) { fac.create(service_name: "fake_v1") }
        let!(:dependency2) { fac.create(service_name: "fake_v1") }

        it "sets depends_on to the specified dependency" do
          step = dependent.replicator.process_state_change("dependency_choice", "2")
          expect(step).to have_attributes(output: include("You're creating a fake_v1 service integration"))
          expect(dependent).to have_attributes(depends_on: be === dependency2)
        end

        it "uses the first dependency if blank" do
          step = dependent.replicator.process_state_change("dependency_choice", " ")
          expect(step).to have_attributes(output: include("You're creating a fake_v1 service integration"))
          expect(dependent).to have_attributes(depends_on: be === dependency1)
        end

        it "errors if the value is invalid or has no dependencies" do
          expect do
            sint.replicator.process_state_change("dependency_choice", "3")
          end.to raise_error(Webhookdb::InvalidPrecondition)
          expect do
            dependent.replicator.process_state_change("dependency_choice", "3")
          end.to raise_error(Webhookdb::InvalidInput)
          expect do
            dependent.replicator.process_state_change("dependency_choice", "abc")
          end.to raise_error(Webhookdb::InvalidInput)
        end
      end

      describe "setting noop_create" do
        it "can return the webhook state machine" do
          sint = Webhookdb::Fixtures.service_integration.
            create(service_name: "fake_webhooks_only_v1", webhook_secret: "x")
          step = sint.replicator.process_state_change("noop_create", nil)
          expect(step).to have_attributes(output: include("The integration creation flow is working correctly"))
          expect(Webhookdb::BackfillJob.all).to be_empty
        end

        it "can return the backfill state machine" do
          sint = Webhookdb::Fixtures.service_integration.
            create(service_name: "fake_backfill_only_v1", backfill_secret: "x")
          step = sint.replicator.process_state_change("noop_create", nil)
          expect(step).to have_attributes(output: include("The backfill flow is working correctly"))
          expect(Webhookdb::BackfillJob.all).to have_length(1)
        end
      end
    end

    describe "webhook_response" do
      it "defers to the protected method" do
        Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.error("hi")
        expect(fake.webhook_response(nil)).to have_attributes(status: 401, reason: "hi")
      end

      it "can override verification" do
        Webhookdb::Replicator::Fake.webhook_response = Webhookdb::WebhookResponse.error("hi")
        expect(fake.webhook_response(nil)).to have_attributes(status: 401, reason: "hi")
        sint.skip_webhook_verification = true
        expect(fake.webhook_response(nil)).to have_attributes(status: 201)
      end
    end

    describe "upsert_webhook" do
      it "logs errors" do
        err = RuntimeError.new("hi")
        expect(fake).to receive(:_upsert_webhook).and_raise(err)
        logs = capture_logs_from(fake.logger, level: :info, formatter: :json) do
          expect do
            fake.upsert_webhook(Webhookdb::Replicator::WebhookRequest.new(
                                  body: {"a" => 1}, headers: {"X" => "1"}, path: "/hi", method: "POST",
                                ))
          end.to raise_error(err)
        end
        expect(logs).to contain_exactly(
          include_json(
            message: eq("upsert_webhook_error"),
            name: eq("Webhookdb::Replicator::Fake"),
            context: {
              error: "hi",
              request: {body: {a: 1}, headers: {X: "1"}, path: "/hi", method: "POST"},
            },
          ),
        )
      end

      it "does not log Amigo errors" do
        err = Amigo::Retry::OrDie.new(1, 1)
        expect(fake).to receive(:_upsert_webhook).and_raise(err)
        logs = capture_logs_from(fake.logger, level: :info, formatter: :json) do
          expect do
            fake.upsert_webhook(Webhookdb::Replicator::WebhookRequest.new(body: {"a" => 1}))
          end.to raise_error(err)
        end
        expect(logs).to be_empty
      end

      describe "" do
        before(:each) do
          sint.organization.prepare_database_connections
        end

        after(:each) do
          sint.organization.remove_related_database
        end

        it "strips null unicode codepoints from JSON" do
          fake.create_table
          # See \u0000 in base.rb for more info
          fake.upsert_webhook_body({"my_id" => "abc", "at" => Time.now.to_s, "has_u0" => "b\u0000\u00004\u0000\\u0000 u"})
          fake.readonly_dataset do |ds|
            expect(ds.first).to include(data: hash_including("has_u0" => "b4\\u0000 u"))
          end
        end
      end
    end

    describe "find_dependent" do
      let(:root_sint) do
        Webhookdb::Fixtures.service_integration.create
      end

      it "returns expected dependent integration with given service name" do
        child_sint = Webhookdb::Fixtures.service_integration.depending_on(root_sint).create
        expect(root_sint.dependents.first).to eq(child_sint)
        result = root_sint.replicator.find_dependent("fake_v1")
        expect(result).to eq(child_sint)
      end

      it "errors if there is no dependent integration with given service name" do
        expect(root_sint.replicator.find_dependent("fake_v2")).to be_nil
        expect do
          root_sint.replicator.find_dependent!("fake_v2")
        end.to raise_error(Webhookdb::InvalidPrecondition, /there is no fake_v2 integration/)
      end

      it "errors if there are multiple dependent integrations with given service name" do
        Webhookdb::Fixtures.service_integration.depending_on(root_sint).create
        Webhookdb::Fixtures.service_integration.depending_on(root_sint).create

        expect do
          root_sint.replicator.find_dependent("fake_v1")
        end.to raise_error(Webhookdb::InvalidPrecondition, /there are multiple fake_v1 integrations/)
      end
    end

    describe "calculate_and_backfill_state_machine", :fake_replicator do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1") }
      let(:svc) { sint.replicator }

      before(:each) do
        _dependent = Webhookdb::Fixtures.service_integration.depending_on(sint).create(
          service_name: "fake_dependent_v1",
          organization: sint.organization,
        )
      end

      it "enques recursive jobs if the step is successful", :async, :do_not_defer_events do
        step, bfjob = svc.calculate_and_backfill_state_machine(incremental: true)
        expect(step).to be_a(Webhookdb::Replicator::StateMachineStep)
        expect(bfjob).to be_nil
        expect(Webhookdb::BackfillJob.all).to be_empty

        sint.update(backfill_secret: "x")
        expect do
          _, bfjob = svc.calculate_and_backfill_state_machine(incremental: false)
        end.to publish("webhookdb.backfilljob.run")
        expect(Webhookdb::BackfillJob.all).to contain_exactly(
          be === bfjob,
          have_attributes(parent_job: be === bfjob),
        )
        expect(bfjob).to have_attributes(incremental: false)
      end

      it "can create jobs non-recursively" do
        sint.update(backfill_secret: "x")
        _, bfjob = svc.calculate_and_backfill_state_machine(incremental: true, recursive: false)
        expect(Webhookdb::BackfillJob.all).to contain_exactly(be === bfjob)
        expect(bfjob).to have_attributes(incremental: true)
      end

      it "passes through job criteria" do
        sint.update(backfill_secret: "x")
        _, bfjob = svc.calculate_and_backfill_state_machine(incremental: false, criteria: {x: 1})
        expect(Webhookdb::BackfillJob.all).to contain_exactly(
          be === bfjob,
          have_attributes(parent_job: be === bfjob),
        )
        expect(bfjob).to have_attributes(incremental: false, criteria: hash_including("x" => 1))
      end

      it "passes through enqueue", :async, :do_not_defer_events do
        sint.update(backfill_secret: "x")
        expect do
          svc.calculate_and_backfill_state_machine(incremental: false, enqueue: false)
        end.to_not publish("webhookdb.backfilljob.run")
      end
    end
  end

  describe "when backfill is not supported" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_webhooks_only_v1") }
    let(:repl) { sint.replicator }

    it "raises an invariant violation when backfilling" do
      expect do
        backfill(sint)
      end.to raise_error(Webhookdb::InvariantViolation, "manual backfill not supported")
    end

    it "can generate documentation without a documentation url" do
      expect(repl).to receive(:documentation_url).and_return(nil)
      expect(repl.backfill_not_supported_message.strip).to eq(<<~S.strip)
        Sorry, you cannot backfill this integration. You may be looking for one of the following:

          webhookdb integrations reset #{sint.table_name}
      S
    end

    it "can generate documentation with a url" do
      expect(repl).to receive(:documentation_url).and_return("http://a.b")
      expect(repl.backfill_not_supported_message.strip).to eq(<<~S.strip)
        Sorry, you cannot manually backfill this integration.
        Please refer to the documentation at http://a.b
        for information on how to refresh data.
      S
    end
  end

  describe "backfill" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "uses job criteria as backfiller keyword arguments" do
      sint = Webhookdb::Fixtures.service_integration(organization: org).
        with_secrets.
        create(service_name: "fake_backfill_with_criteria_v1")
      sint.replicator.create_table
      bfjob = Webhookdb::BackfillJob.create(
        service_integration: sint,
        incremental: false,
        criteria: {x: 1, "y" => "b"},
      )
      sint.replicator.backfill(bfjob)
      expect(sint.replicator.admin_dataset(&:all)).to contain_exactly(
        include(
          at: match_time("2022-01-01T00:00:00Z"),
          backfill_kwargs: hash_including("x" => 1, "y" => "b"),
          my_id: "x",
        ),
      )
    end
  end
end

# rubocop:enable Layout/LineLength
