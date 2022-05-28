# frozen_string_literal: true

require "webhookdb/db_adapter"

RSpec.describe Webhookdb::DBAdapter do
  describe "adapter" do
    it "returns the pg adapter for postgres:// conn strings" do
      expect(described_class.adapter("postgres://")).to be_a(described_class::PG)
    end

    it "errors for an unknown connection string" do
      expect do
        described_class.adapter("randodb://")
      end.to raise_error(described_class::UnsupportedAdapter)
    end
  end

  describe "Webhookdb::DBAdapter::PG" do
    let(:ad) { described_class::PG.new }
    let(:sch) { described_class::Schema }
    let(:tbl) { described_class::Table }
    let(:col) { described_class::Column }
    let(:ind) { described_class::Index }
    let(:tbldesc) { described_class::TableDescriptor }
    let(:coltype) { described_class::ColumnTypes }

    describe "create_schema_sql" do
      it "returns the query" do
        expect(ad.create_schema_sql(sch.new(name: :foo))).to eq("CREATE SCHEMA foo")
      end

      it "escapes identifiers, and can use if_not_exists" do
        sql = ad.create_schema_sql(sch.new(name: :from), if_not_exists: true)
        expect(sql).to eq("CREATE SCHEMA IF NOT EXISTS \"from\"")
      end
    end

    describe "create_table_sql" do
      it "returns the query" do
        sql = ad.create_table_sql(
          tbl.new(name: :foo),
          [col.new(name: :c1, type: coltype::INTEGER)],
        )
        expect(sql).to eq("CREATE TABLE foo (\n  c1 integer\n)")
      end

      it "escapes identifiers, can use if_not_exists, and can use an explicit schema" do
        sql = ad.create_table_sql(
          tbl.new(name: :from, schema: sch.new(name: :blah)),
          [col.new(name: :c1, type: coltype::INTEGER), col.new(name: :c2, type: coltype::TEXT)],
          if_not_exists: true,
        )
        expect(sql).to eq("CREATE TABLE IF NOT EXISTS blah.\"from\" (\n  c1 integer,\n  c2 text\n)")
      end
    end

    describe "create_index_sql" do
      it "returns the query" do
        sql = ad.create_index_sql(
          ind.new(name: :foo, table: tbl.new(name: :tbl), targets: [col.new(name: :c1, type: coltype::TEXT)]),
        )
        expect(sql).to eq("CREATE INDEX IF NOT EXISTS foo ON tbl (c1)")
      end

      it "escapes identifiers and can be unique" do
        sql = ad.create_index_sql(
          ind.new(
            name: :from,
            table: tbl.new(name: :if),
            targets: [col.new(name: :not, type: coltype::TEXT), col.new(name: :in, type: coltype::TEXT)],
            unique: true,
          ),
        )
        expect(sql).to eq("CREATE UNIQUE INDEX IF NOT EXISTS \"from\" ON if (\"not\", \"in\")")
      end
    end

    describe "column_create_sql" do
      it "returns the query" do
        sql = ad.column_create_sql(col.new(name: :c1, type: coltype::TEXT))
        expect(sql).to eq("c1 text")
      end

      it "works for primary keys" do
        sql = ad.column_create_sql(col.new(name: :c1, type: coltype::PKEY))
        expect(sql).to eq("c1 bigserial PRIMARY KEY")
      end

      it "works for unique" do
        sql = ad.column_create_sql(col.new(name: :c1, type: coltype::TEXT, unique: true))
        expect(sql).to eq("c1 text UNIQUE NOT NULL")
      end

      it "works for non-null" do
        sql = ad.column_create_sql(col.new(name: :c1, type: coltype::TEXT, nullable: false))
        expect(sql).to eq("c1 text NOT NULL")
      end

      it "escapes identifiers" do
        sql = ad.column_create_sql(col.new(name: :from, type: coltype::TEXT))
        expect(sql).to eq("\"from\" text")
      end
    end
  end
end
