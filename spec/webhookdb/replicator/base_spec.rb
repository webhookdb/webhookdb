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

      prepared_hash = s._prepare_for_insert(resource, nil, nil)
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
      prepared_hash = s._prepare_for_insert(new_resource, nil, nil)
      expect(prepared_hash).to eq({id: "productABC", item: "Banana", quantity: 11})
    end
  end
end
