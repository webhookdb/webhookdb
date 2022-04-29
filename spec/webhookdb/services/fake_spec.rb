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
            Webhookdb::Services::Column.new(:c2, "timestamptz", index: true),
            Webhookdb::Services::Column.new(:c3, "date"),
            Webhookdb::Services::Column.new(:c4, "text", index: true),
          ]
        end
        expect(fake.ensure_all_columns_sql).to eq(%{ALTER TABLE #{fake.table_sym} ADD "c2" timestamptz ;
CREATE INDEX IF NOT EXISTS c2_idx ON #{fake.table_sym} ("c2");
ALTER TABLE #{fake.table_sym} ADD "c3" date ;
ALTER TABLE #{fake.table_sym} ADD "c4" text ;
CREATE INDEX IF NOT EXISTS c4_idx ON #{fake.table_sym} ("c4");})
        fake.ensure_all_columns
        fake.readonly_dataset { |ds| expect(ds.columns).to eq([:pk, :my_id, :at, :data, :c2, :c3, :c4]) }
      end
    end
  end
end
