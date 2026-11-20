# frozen_string_literal: true

require "webhookdb/db_adapter"

RSpec.describe Webhookdb::DBAdapter do
  let(:sch) { described_class::Schema }
  let(:tbl) { described_class::Table }
  let(:col) { described_class::Column }
  let(:ind) { described_class::Index }
  let(:coltype) { described_class::ColumnTypes }

  mock_conn = Class.new(Webhookdb::DBAdapter::Connection) do
    attr_reader :calls

    def initialize
      super
      @calls = []
    end

    def execute(*a, **kw)
      @calls << [:execute, a, kw]
    end

    alias_method :<<, :execute

    def using
      yield self
    end

    def copy_into(*a, **kw)
      @calls << [:copy_into, a, kw]
    end
  end

  describe "adapter" do
    it "returns the pg adapter for postgres:// conn strings" do
      expect(described_class.adapter("postgres://")).to be_a(described_class::PG)
    end

    it "returns the pg adapter for snowflake:// conn strings" do
      expect(described_class.adapter("snowflake://")).to be_a(described_class::Snowflake)
    end

    it "errors for an unknown connection string" do
      expect do
        described_class.adapter("randodb://")
      end.to raise_error(described_class::UnsupportedAdapter)
    end
  end

  describe described_class::PG do
    let(:ad) { described_class::PG.new }

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

      describe "partitioning" do
        it "creates a hash partitioned table" do
          sql = ad.create_table_sql(
            tbl.new(name: :foo),
            [
              col.new(name: :c1, type: coltype::INTEGER, pk: true),
              col.new(name: :c2, type: coltype::TEXT, unique: true),
            ],
            partition: described_class::Partitioning.new(by: :hash, column: :c1),
          )
          expect(sql).to eq(<<~SQL.strip)
            CREATE TABLE foo (
              c1 serial,
              c2 text,
              PRIMARY KEY (c1),
              UNIQUE (c1, c2)
            )
            PARTITION BY HASH (c1)
          SQL
        end

        it "creates a range partitioned table" do
          sql = ad.create_table_sql(
            tbl.new(name: :foo),
            [
              col.new(name: :c1, type: coltype::INTEGER, pk: true),
            ],
            partition: described_class::Partitioning.new(by: :range, column: :c1),
          )
          expect(sql).to eq(<<~SQL.strip)
            CREATE TABLE foo (
              c1 serial,
              PRIMARY KEY (c1)
            )
            PARTITION BY RANGE (c1)
          SQL
        end

        it "errors for invalid partition by" do
          expect do
            ad.create_table_sql(
              tbl.new(name: :foo),
              [],
              partition: described_class::Partitioning.new(by: :foo, column: :c1),
            )
          end.to raise_error(/unknown partition method/)
        end

        it "can partition on a column other than the pk" do
          sql = ad.create_table_sql(
            tbl.new(name: :foo),
            [
              col.new(name: :c1, type: coltype::BIGINT, pk: true),
              col.new(name: :c2, type: coltype::BIGINT),
            ],
            partition: described_class::Partitioning.new(by: :hash, column: :c2),
          )
          expect(sql).to eq(<<~SQL.strip)
            CREATE TABLE foo (
              c1 bigserial,
              c2 bigint,
              PRIMARY KEY (c2, c1)
            )
            PARTITION BY HASH (c2)
          SQL
        end

        it "can use a bigserial pk" do
          sql = ad.create_table_sql(
            tbl.new(name: :foo),
            [
              col.new(name: :c1, type: coltype::BIGINT, pk: true),
            ],
            partition: described_class::Partitioning.new(by: :hash, column: :c1),
          )
          expect(sql).to eq("CREATE TABLE foo (\n  c1 bigserial,\n  PRIMARY KEY (c1)\n)\nPARTITION BY HASH (c1)")
        end

        it "can use a non-serial pk" do
          sql = ad.create_table_sql(
            tbl.new(name: :foo),
            [
              col.new(name: :c1, type: coltype::TEXT, pk: true),
            ],
            partition: described_class::Partitioning.new(by: :hash, column: :c1),
          )
          # NOTE: This won't actually work for a partition, it is just here for better testing
          # and to have a place to figure this out if needed in the future.
          expect(sql).to eq("CREATE TABLE foo (\n  c1 text,\n  PRIMARY KEY (c1)\n)\nPARTITION BY HASH (c1)")
        end

        it "can create hash partitions" do
          sql = ad.create_hash_partition_sql(tbl.new(name: :foo), 2, 1)
          expect(sql).to eq("CREATE TABLE foo_1 PARTITION OF foo FOR VALUES WITH (MODULUS 2, REMAINDER 1)")
        end
      end
    end

    describe "create_index_sql" do
      it "returns the query" do
        sql = ad.create_index_sql(
          ind.new(name: :foo, table: tbl.new(name: :tbl), targets: [col.new(name: :c1, type: coltype::TEXT)]),
          concurrently: false,
        )
        expect(sql).to eq("CREATE INDEX IF NOT EXISTS foo ON tbl (c1)")
      end

      it "can use concurrently" do
        sql = ad.create_index_sql(
          ind.new(name: :foo, table: tbl.new(name: :tbl), targets: [col.new(name: :c1, type: coltype::TEXT)]),
          concurrently: true,
        )
        expect(sql).to eq("CREATE INDEX CONCURRENTLY IF NOT EXISTS foo ON tbl (c1)")
      end

      it "escapes identifiers and can be unique" do
        sql = ad.create_index_sql(
          ind.new(
            name: :from,
            table: tbl.new(name: :if),
            targets: [col.new(name: :not, type: coltype::TEXT), col.new(name: :in, type: coltype::TEXT)],
            unique: true,
          ),
          concurrently: false,
        )
        expect(sql).to eq("CREATE UNIQUE INDEX IF NOT EXISTS \"from\" ON if (\"not\", \"in\")")
      end

      it "can use partial indices" do
        sql = ad.create_index_sql(
          ind.new(
            name: :foo,
            table: tbl.new(name: :tbl),
            targets: [col.new(name: :c1, type: coltype::TEXT)],
            where: Sequel[:c1] !~ nil,
          ),
          concurrently: false,
        )
        expect(sql).to eq("CREATE INDEX IF NOT EXISTS foo ON tbl (c1) WHERE (\"c1\" IS NOT NULL)")
      end
    end

    describe "create_column_sql" do
      it "returns the query" do
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::TEXT))
        expect(sql).to eq("c1 text")
      end

      it "works for primary keys" do
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::BIGINT, pk: true))
        expect(sql).to eq("c1 bigserial PRIMARY KEY")
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::INTEGER, pk: true))
        expect(sql).to eq("c1 serial PRIMARY KEY")
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::TEXT, pk: true))
        expect(sql).to eq("c1 text PRIMARY KEY")
      end

      it "works for unique" do
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::TEXT, unique: true))
        expect(sql).to eq("c1 text UNIQUE NOT NULL")
      end

      it "works for non-null" do
        sql = ad.create_column_sql(col.new(name: :c1, type: coltype::TEXT, nullable: false))
        expect(sql).to eq("c1 text NOT NULL")
      end

      it "escapes identifiers" do
        sql = ad.create_column_sql(col.new(name: :from, type: coltype::TEXT))
        expect(sql).to eq("\"from\" text")
      end
    end

    describe "add_column_sql" do
      let(:t) { tbl.new(name: :tbl) }

      it "returns the query" do
        sql = ad.add_column_sql(t, col.new(name: :c1, type: coltype::TEXT))
        expect(sql).to eq("ALTER TABLE tbl ADD COLUMN c1 text")

        sql = ad.add_column_sql(t, col.new(name: :c1, type: coltype::TEXT), if_not_exists: true)
        expect(sql).to eq("ALTER TABLE tbl ADD COLUMN IF NOT EXISTS c1 text")
      end
    end

    it "can verify its connection" do
      expect { ad.verify_connection(ENV.fetch("DATABASE_URL", nil)) }.to_not raise_error
    end

    it "can merge from csv" do
      expect(SecureRandom).to receive(:hex).and_return("0420bff4")
      c = mock_conn.new
      ad.merge_from_csv(c, "xyz", tbl.new(name: :foo), :mypk, [:x, :y])
      # rubocop:disable Layout/LineLength
      expect(c.calls).to eq(
        [
          [:execute, ["CREATE TEMP TABLE foo_staging_0420bff4 (LIKE foo)"], {}],
          [:copy_into, [:foo_staging_0420bff4], {data: "xyz", options: "DELIMITER ',', HEADER true, FORMAT csv"}],
          [:execute, ["UPDATE foo AS tgt\nSET x = src.x, y = src.y FROM\n(SELECT * FROM foo_staging_0420bff4 WHERE mypk IN (SELECT mypk FROM foo)) src\nWHERE tgt.mypk = src.mypk;\n\nINSERT INTO foo SELECT * FROM foo_staging_0420bff4 WHERE mypk NOT IN (SELECT mypk FROM foo);"], {}],
        ],
      )
      # rubocop:enable Layout/LineLength
    end
  end

  describe described_class::Snowflake do
    let(:ad) { described_class::Snowflake.new }

    it "can create a table" do
      sql = ad.create_table_sql(
        tbl.new(name: :foo, schema: sch.new(name: :bar)),
        [col.new(name: :c1, type: coltype::INTEGER)],
      )
      expect(sql).to eq("CREATE TABLE bar.foo (\n  c1 integer\n)")
    end

    it "raises if trying to create an index" do
      expect { ad.create_index_sql }.to raise_error(/Snowflake does not support indices/)
    end

    it "executes using the cli" do
      c = ad.connection("x://y.z")
      expect(Webhookdb::Snowflake).to receive(:run_cli).with("x://y.z", "SELECT 2")
      c.execute("SELECT 2")
    end

    it "can verify its connection" do
      expect(Webhookdb::Snowflake).to receive(:run_cli).with("x://y.z", "SELECT 1")
      ad.verify_connection("x://y.z")
    end

    it "can merge from csv" do
      c = mock_conn.new
      t = tbl.new(name: :foo, schema: sch.new(name: :bar))
      pkcol = col.new(name: :mypk, type: coltype::INTEGER)
      copycols = [
        col.new(name: :c1, type: coltype::INTEGER),
        col.new(name: :c2, type: coltype::INTEGER),
      ]
      tmp = Tempfile.new
      ad.merge_from_csv(c, tmp, t, pkcol, copycols)
      expect(c.calls.to_s).to include("CREATE STAGE bar.whdb_tempstage_")
    end

    it "can add a new column to a table" do
      sql = ad.add_column_sql(tbl.new(name: :foo), col.new(name: :bar, type: coltype::INTEGER))
      expect(sql).to eq("ALTER TABLE foo ADD COLUMN bar integer")
    end

    it "can add a column with if_not_exists" do
      t = tbl.new(name: :foo, schema: sch.new(name: :bar))
      sql = ad.add_column_sql(t, col.new(name: :bar, type: coltype::INTEGER), if_not_exists: true)
      expect(sql).to include("EXECUTE IMMEDIATE $$")
    end
  end

  describe "default sql helpers" do
    cls = Class.new do
      include Webhookdb::DBAdapter::DefaultSql

      def identifier_quote_char
        return '"'
      end
    end
    inst = cls.new

    describe "escape_identifier" do
      it "raises for invalid identifiers" do
        expect { inst.escape_identifier("hi ; there") }.to raise_error(ArgumentError, /invalid identifier/)
        expect { inst.escape_identifier("hi-there") }.to raise_error(ArgumentError, /invalid identifier/)
        expect { inst.escape_identifier("2hi") }.to raise_error(ArgumentError, /invalid identifier/)
        expect { inst.escape_identifier("") }.to raise_error(ArgumentError, /invalid identifier/)
      end

      it "escapes what needs escaping" do
        expect(inst.escape_identifier("hi")).to eq("hi")
        expect(inst.escape_identifier("hi there")).to eq('"hi there"')
        expect(inst.escape_identifier("select")).to eq('"select"')
        expect(inst.escape_identifier("a")).to eq("a")
      end
    end
  end

  describe described_class::Partition do
    it "formats index names" do
      # rubocop:disable Naming/VariableNumber, Layout/LineLength
      part = described_class.new(
        parent_table: Webhookdb::DBAdapter::Table.new(
          name: :tbl,
          schema: Webhookdb::DBAdapter::Schema.new(name: :sch),
        ),
        partition_name: :part_1,
        suffix: :_1,
      )
      expect(part.index_name("shorty")).to eq(:shorty_1)
      expect(part.index_name("x" * 63)).to eq(:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_1)
      expect(part.index_name("x" * 99)).to eq(:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_1)
      expect(part.index_name(("x" * 59) + "_idx")).to eq(:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_idx_1)
      expect(part.index_name(("x" * 62) + "_i")).to eq(:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_i_1)
      expect(part.index_name(("x" * 31) + "_" + ("y" * 30))).to eq(:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_yyyyyyyyyyyyyyyyyyyyyyyyyyyyy_1)
      expect(part.index_name("foo_bar_idx")).to eq(:foo_bar_idx_1)
      # rubocop:enable Naming/VariableNumber, Layout/LineLength
    end
  end
end
