# frozen_string_literal: true

RSpec.describe Webhookdb::Services::Base, :db do
  describe "create_tables_sql" do
    svc_cls = Class.new(described_class) do
      def _remote_key_column
        return Webhookdb::Services::Column.new(:remotecol, "text")
      end
    end
    let(:sint) { Webhookdb::Fixtures.service_integration(table_name: "mytbl").instance }

    it "generates the correct sql" do
      s = svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
          pk bigserial PRIMARY KEY,
          "remotecol" text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
      S
    end

    it "denormalizes and indexes denormalized columns that specify they should be indexed" do
      test_svc_cls = Class.new(svc_cls) do
        def _denormalized_columns
          return [
            Webhookdb::Services::Column.new(:denorm1, "text", index: true),
            Webhookdb::Services::Column.new(:denorm2, "int"),
            Webhookdb::Services::Column.new(:denorm3, "int", index: true),
            Webhookdb::Services::Column.new(:denorm4, "int", index: false),
          ]
        end
      end
      s = test_svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
          pk bigserial PRIMARY KEY,
          "remotecol" text UNIQUE NOT NULL,
          "denorm1" text ,
          "denorm2" int ,
          "denorm3" int ,
          "denorm4" int ,
          data jsonb NOT NULL
        );
        CREATE INDEX IF NOT EXISTS denorm1_idx ON mytbl ("denorm1");
        CREATE INDEX IF NOT EXISTS denorm3_idx ON mytbl ("denorm3");
      S
    end

    it "creates enrichment tables" do
      test_svc_cls = Class.new(svc_cls) do
        def _create_enrichment_tables_sql
          return "CREATE TABLE foobar(x text);"
        end
      end
      s = test_svc_cls.new(sint)
      expect(s._create_table_sql).to eq(<<~S.rstrip)
        CREATE TABLE mytbl (
          pk bigserial PRIMARY KEY,
          "remotecol" text UNIQUE NOT NULL,
          data jsonb NOT NULL
        );
        CREATE TABLE foobar(x text);
      S
    end
  end
end
