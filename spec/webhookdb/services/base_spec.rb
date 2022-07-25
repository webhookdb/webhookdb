# frozen_string_literal: true

RSpec.describe Webhookdb::Services::Base, :db do
  describe "create_tables_sql" do
    svc_cls = Class.new(described_class) do
      def _remote_key_column
        return Webhookdb::Services::Column.new(:remotecol, Webhookdb::DBAdapter::ColumnTypes::TEXT)
      end
    end
    let(:sint_fac) { Webhookdb::Fixtures.service_integration(table_name: "mytbl") }

    it "generates the correct sql" do
      s = svc_cls.new(sint_fac.instance)
      expect(s.create_table_sql).to eq(<<~S.rstrip)
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
      expect(s.create_table_sql).to eq(<<~S.rstrip)
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
            Webhookdb::Services::Column.new(:denorm1, Webhookdb::DBAdapter::ColumnTypes::TEXT, index: true),
            Webhookdb::Services::Column.new(:denorm2, Webhookdb::DBAdapter::ColumnTypes::INTEGER),
            Webhookdb::Services::Column.new(:from, Webhookdb::DBAdapter::ColumnTypes::INTEGER, index: true),
            Webhookdb::Services::Column.new(:denorm4, Webhookdb::DBAdapter::ColumnTypes::INTEGER, index: false),
          ]
        end
      end
      sint = sint_fac.instance
      sint.opaque_id = "opaq"
      s = test_svc_cls.new(sint)
      expect(s.create_table_sql).to eq(<<~S.rstrip)
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

    it "creates enrichment tables" do
      test_svc_cls = Class.new(svc_cls) do
        def _enrichment_tables_descriptors
          tbl = Webhookdb::DBAdapter::Table.new(name: :enrichmenttbl)
          cols = [Webhookdb::DBAdapter::Column.new(name: :x, type: Webhookdb::DBAdapter::ColumnTypes::TEXT)]
          return [
            Webhookdb::DBAdapter::TableDescriptor.new(
              table: tbl,
              columns: cols,
              indices: [Webhookdb::DBAdapter::Index.new(name: :idx, table: tbl, targets: cols)],
            ),
          ]
        end
      end
      s = test_svc_cls.new(sint_fac.create)
      expect(s.create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE public.mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
        CREATE TABLE public.enrichmenttbl (
          x text
        );
        CREATE INDEX IF NOT EXISTS idx ON public.enrichmenttbl (x);
      S
    end
  end
end
