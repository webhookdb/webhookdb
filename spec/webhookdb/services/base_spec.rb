# frozen_string_literal: true

RSpec.describe Webhookdb::Services::Base, :db do
  describe "create_tables_sql" do
    svc_cls = Class.new(described_class) do
      def _remote_key_column
        return Webhookdb::Services::Column.new(:remotecol, Webhookdb::DBAdapter::ColumnTypes::TEXT)
      end
    end
    let(:sint) { Webhookdb::Fixtures.service_integration(table_name: "mytbl").instance }

    it "generates the correct sql" do
      s = svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
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
      s = test_svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          denorm1 text,
          denorm2 integer,
          "from" integer,
          denorm4 integer,
          data jsonb NOT NULL
        );
        CREATE INDEX IF NOT EXISTS denorm1_idx ON mytbl (denorm1);
        CREATE INDEX IF NOT EXISTS from_idx ON mytbl ("from");
      S
    end

    it "creates enrichment tables" do
      test_svc_cls = Class.new(svc_cls) do
        def _enrichment_tables_descriptors
          return [
            Webhookdb::DBAdapter::TableDescriptor.new(
              table: Webhookdb::DBAdapter::Table.new(name: :foobar),
              columns: [Webhookdb::DBAdapter::Column.new(name: :x, type: Webhookdb::DBAdapter::ColumnTypes::TEXT)],
            ),
          ]
        end
      end
      s = test_svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
          pk bigserial PRIMARY KEY,
          remotecol text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
        CREATE TABLE foobar (
          x text
        );
      S
    end
  end
end
