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
    it "denormalizes and indexes denormalized columns" do
      test_svc_cls = Class.new(svc_cls) do
        def _denormalized_columns
          return [
            Webhookdb::Services::Column.new(:denorm1, "text"),
            Webhookdb::Services::Column.new(:denorm2, "int"),
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
          data jsonb NOT NULL
        );
        CREATE INDEX IF NOT EXISTS denorm1_idx ON mytbl ("denorm1");
        CREATE INDEX IF NOT EXISTS denorm2_idx ON mytbl ("denorm2");
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
