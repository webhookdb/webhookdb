# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator::Base, :db do
  describe "create_tables_modification" do
    svc_cls = Class.new(described_class) do
      def _remote_key_column
        return Webhookdb::Replicator::Column.new(:remotecol, Webhookdb::DBAdapter::ColumnTypes::TEXT)
      end
    end
    let(:sint_fac) { Webhookdb::Fixtures.service_integration(table_name: "mytbl") }

    it "generates the correct sql" do
      s = svc_cls.new(sint_fac.instance)
      expect(s.create_table_modification.to_s).to eq(<<~S.rstrip)
        CREATE TABLE public.mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
      S
    end

    it "adds an enrichment column where required" do
      enrichment_svc_class = Class.new(described_class) do
        attr_accessor :store_enrichment_body

        def _remote_key_column
          return Webhookdb::Replicator::Column.new(:remotecol, Webhookdb::DBAdapter::ColumnTypes::TEXT)
        end

        def _store_enrichment_body? = self.store_enrichment_body
      end
      s = enrichment_svc_class.new(sint_fac.instance)
      s.store_enrichment_body = true
      expect(s.create_table_modification.to_s).to eq(<<~S.rstrip)
        CREATE TABLE public.mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          enrichment jsonb,
          data jsonb NOT NULL
        );
      S
      s.store_enrichment_body = false
      expect(s.create_table_modification.to_s).to eq(<<~S.rstrip)
        CREATE TABLE public.mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
      S
    end

    it "can use a specific schema" do
      org = Webhookdb::Fixtures.organization(replication_schema: "hi there").create
      s = svc_cls.new(sint_fac.create(organization: org))
      expect(s.create_table_modification.to_s).to eq(<<~S.rstrip)
        CREATE TABLE "hi there".mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
      S
    end

    it "denormalizes and indexes denormalized columns that specify they should be indexed" do
      test_svc_cls = Class.new(svc_cls) do
        def _denormalized_columns
          return [
            Webhookdb::Replicator::Column.new(:denorm1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Replicator::Column.new(:denorm2, Webhookdb::DBAdapter::ColumnTypes::INTEGER),
            Webhookdb::Replicator::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::INTEGER, index: true),
            Webhookdb::Replicator::Column.new(:denorm4, Webhookdb::DBAdapter::ColumnTypes::INTEGER, index: false),
          ]
        end
      end
      sint = sint_fac.instance
      sint.opaque_id = "opaq"
      s = test_svc_cls.new(sint)
      expect(s.create_table_modification.to_s).to eq(<<~S.rstrip)
        CREATE TABLE public.mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          denorm1 text,
          denorm2 integer,
          "from" integer,
          denorm4 integer,
          data jsonb NOT NULL
        );
        CREATE INDEX IF NOT EXISTS opaq_denorm1_idx ON public.mytbl (denorm1);
        CREATE INDEX IF NOT EXISTS opaq_from_idx ON public.mytbl ("from");
      S
    end
  end

  describe "_prepare_for_insert" do
    svc_cls = Class.new(described_class) do
      def _remote_key_column
        return Webhookdb::Replicator::Column.new(:id, Webhookdb::DBAdapter::ColumnTypes::TEXT)
      end

      def _denormalized_columns
        return [
          Webhookdb::Replicator::Column.new(:item, Webhookdb::DBAdapter::ColumnTypes::TEXT, data_key: "product_name"),
          Webhookdb::Replicator::Column.new(:quantity, Webhookdb::DBAdapter::ColumnTypes::INTEGER,
                                            converter: Webhookdb::Replicator::Column::CONV_TO_I,),
          Webhookdb::Replicator::Column.new(:notes, Webhookdb::DBAdapter::ColumnTypes::TEXT, skip_nil: true),
        ]
      end
    end

    let(:sint_fac) { Webhookdb::Fixtures.service_integration }

    let(:resource) do
      {
        "id" => "productABC",
        "product_name" => "Banana",
        "quantity" => "12",
        "notes" => "They are yellow",
      }
    end

    it "retrieves all columns and converts values" do
      s = svc_cls.new(sint_fac.instance)

      prepared_hash = s._prepare_for_insert(resource, nil, nil, nil)
      expect(prepared_hash).to eq({id: "productABC", item: "Banana", quantity: 12, notes: "They are yellow"})
    end

    it "respects skip_nil behavior" do
      s = svc_cls.new(sint_fac.instance)
      new_resource =
        {
          "id" => "productABC",
          "product_name" => "Banana",
          "quantity" => "11",
          "notes" => nil,
        }
      prepared_hash = s._prepare_for_insert(new_resource, nil, nil, nil)
      expect(prepared_hash).to eq({id: "productABC", item: "Banana", quantity: 11})
    end
  end

  describe "backfill", :fake_replicator do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(backfill_key: "abc") }

    before(:each) do
      sint.organization.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    def body(id)
      return {"my_id" => id, "at" => "Thu, 30 Jul 2016 21:12:33 +0000"}
    end

    describe "with parallelism" do
      let(:fetches) { [] }
      let(:upserts) { [] }

      it "waits for all backfillers to return" do
        cls = Class.new(Webhookdb::Backfiller) do
          def initialize(sint, pages, all_fetches, upserts)
            @sint = sint
            @pages = pages
            @fetches = []
            @all_fetches = all_fetches
            @upserts = upserts
            super()
          end

          def handle_item(item) = @upserts << item

          def fetch_backfill_page(*args)
            @fetches << args
            @all_fetches << args
            return @pages[@fetches.size - 1]
          end
        end
        bf1 = cls.new(
          sint,
          [
            [[body("2"), body("3"), body("4")], "b"],
            [[body("5")], nil],
          ],
          fetches,
          upserts,
        )
        bf2 = cls.new(
          sint,
          [
            [[body("15")], nil],
          ],
          fetches,
          upserts,
        )
        bf3 = cls.new(
          sint,
          [
            [[body("22"), body("23")], "a"],
            [[body("25")], nil],
          ],
          fetches,
          upserts,
        )
        replicator = sint.replicator
        expect(sint).to receive(:replicator).and_return(replicator)
        replicator.define_singleton_method(:_parallel_backfill) { 2 }
        replicator.define_singleton_method(:_backfillers) { [bf1, bf2, bf3] }
        backfill(replicator)
        expect(fetches).to contain_exactly(
          [nil, {last_backfilled: nil}],
          ["b", {last_backfilled: nil}],
          [nil, {last_backfilled: nil}],
          ["a", {last_backfilled: nil}],
          [nil, {last_backfilled: nil}],
        )
        expect(upserts.map { |u| u["my_id"] }).to contain_exactly("2", "3", "4", "5", "22", "23", "25", "15")
      end

      it "reraises any errors" do
        cls = Class.new(Webhookdb::Backfiller) do
          def fetch_backfill_page(*)
            raise "hello"
          end
        end
        bf = cls.new
        replicator = sint.replicator
        expect(sint).to receive(:replicator).and_return(replicator)
        replicator.define_singleton_method(:_parallel_backfill) { 2 }
        replicator.define_singleton_method(:_backfillers) { [bf] }
        expect do
          backfill(replicator)
        end.to raise_error(RuntimeError, "hello")
      end
    end

    describe "when an error occurs" do
      it "calls the error handler" do
        stub_request(:get, "https://fake-integration/?token=").
          to_return(status: 500, body: "Error")
        replicator = sint.replicator
        expect(sint).to receive(:replicator).and_return(replicator)
        ex = RuntimeError.new("hi")
        expect(replicator).to receive(:on_backfill_error).with(be_a(Exception)).and_raise(ex)
        expect { backfill(sint) }.to raise_error(ex)
      end

      it "raises the original error if not handled" do
        stub_request(:get, "https://fake-integration/?token=").
          to_return(status: 500, body: "Error")
        replicator = sint.replicator
        expect { backfill(replicator) }.to raise_error(Amigo::Retry::OrDie, /status: 500, method: GET/)
      end
    end
  end

  describe "ServiceBackfiller" do
    describe "fetch_backfill_page" do
      o = Class.new do
        def _fetch_backfill_page(*)
          return Webhookdb::Http.get("https://fake.com", timeout: 1, logger: nil).parsed_response
        end
      end

      it "calls _fetch_backfill_page" do
        req = stub_request(:get, "https://fake.com/").and_return(json_response([[], nil]))
        bf = described_class::ServiceBackfiller.new(o.new)
        bf.backfill(nil)
        expect(req).to have_been_made
      end

      it "raises RetryOrDie on timeouts" do
        req = stub_request(:get, "https://fake.com/").to_timeout
        bf = described_class::ServiceBackfiller.new(o.new)
        expect { bf.backfill(nil) }.to raise_error(Amigo::Retry::OrDie)
        expect(req).to have_been_made
      end

      it "raises RetryOrDie on socket errors" do
        req = stub_request(:get, "https://fake.com/").to_raise(SocketError)
        bf = described_class::ServiceBackfiller.new(o.new)
        expect { bf.backfill(nil) }.to raise_error(Amigo::Retry::OrDie)
        expect(req).to have_been_made
      end

      it "raises RetryOrDie on 5xx responses" do
        req = stub_request(:get, "https://fake.com/").and_return(status: 503)
        bf = described_class::ServiceBackfiller.new(o.new)
        expect { bf.backfill(nil) }.to raise_error(Amigo::Retry::OrDie)
        expect(req).to have_been_made
      end

      it "uses a default backoff/retry" do
        bf = described_class::ServiceBackfiller.new(o.new)
        expect(bf.server_error_retries).to eq(2)
        expect(bf.server_error_backoff).to eq(63)
      end

      it "can read backoff/retry from the service" do
        o2 = Class.new(o) do
          define_method(:backfiller_server_error_retries) { 5 }
          define_method(:backfiller_server_error_backoff) { 100 }
        end
        bf = described_class::ServiceBackfiller.new(o2.new)
        expect(bf.server_error_retries).to eq(5)
        expect(bf.server_error_backoff).to eq(100)
      end

      it "propogates other responses" do
        req = stub_request(:get, "https://fake.com/").and_return({status: 404}, {status: 404}, {status: 404})
        expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice
        bf = described_class::ServiceBackfiller.new(o.new)
        expect { bf.backfill(nil) }.to raise_error(Webhookdb::Http::Error)
        expect(req).to have_been_made.times(3)
      end
    end
  end
end
