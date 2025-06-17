# frozen_string_literal: true

require "pg"

require "webhookdb/db_adapter/default_sql"

class Webhookdb::DBAdapter::PG < Webhookdb::DBAdapter
  include Webhookdb::DBAdapter::ColumnTypes
  include Webhookdb::DBAdapter::DefaultSql

  VERIFY_TIMEOUT = 2
  VERIFY_STATEMENT = "SELECT 1"

  def identifier_quote_char = '"'

  def create_index_sql(index, concurrently:)
    tgts = index.targets.map { |c| self.escape_identifier(c.name) }.join(", ")
    uniq = index.unique ? " UNIQUE" : ""
    concurrent = concurrently ? " CONCURRENTLY" : ""
    idxname = self.escape_identifier(index.name)
    tblname = self.qualify_table(index.table)
    where = ""
    where = " " + Webhookdb::Customer.where(index.where).sql.delete_prefix('SELECT * FROM "customers" ') if index.where
    return "CREATE#{uniq} INDEX#{concurrent} IF NOT EXISTS #{idxname} ON #{tblname} (#{tgts})#{where}"
  end

  def create_index_sqls(index, concurrently:, partitions: [])
    # For unpartitioned tables, we can create the index as normal.
    return super if partitions.empty?
    # For partitioned tables, we need to be careful with how we create the indexes.
    # If the overall function gets interrupted (the process gets killed, etc.), we can be left with an invalid index.
    # We can minimize this possibility by doing the following:
    # - Create an index for each partition, if it does not exist already.
    #   - This is done outside a transaction, since it may happen concurrently.
    # - Then we open a transaction for the final steps, which are all very fast/metadata-only.
    #   - A transaction here ensures that we only have the 'parent' index in a successful, completed state.
    # - Create the 'parent' index 'ONLY ON' the parent table.
    #   - This is a very fast operation.
    # - Attach all the partition indexes to the parent index. This is metadata-only so also very fast.
    #   - At this point, the parent index should be valid.
    # - These steps mean that, at any point, the process can be interrupted and resumed,
    #   without losing progress:
    #   - The concurrent index creation for the partitions can fail, and result in an invalid index;
    #     but the next call to update the schema will drop invalid indexes for the table.
    #     Note that successfully created, but unattached, indexes for a partition are valid.
    #   - The parent index creation, and attaching partitions to it, are atomic.
    #
    create_partition_indexes = []
    attach_indexes = []
    partitions.each do |partition|
      partition_idx = index.change(table: partition.partition_table, name: "#{index.name}#{partition.suffix}")
      create_partition_indexes << self.create_index_sql(partition_idx, concurrently:)
      attach_indexes << "ALTER INDEX #{index.name} ATTACH PARTITION #{partition_idx.name}"
    end
    result = []
    result.concat(create_partition_indexes)
    result << "BEGIN"
    result << self.create_index_sql(index, concurrently: false).gsub(" ON ", " ON ONLY ")
    result.concat(attach_indexes)
    result << "COMMIT"
    return result
  end

  def create_table_sql(table, columns, if_not_exists: false, partition: nil)
    columns = columns.to_a
    createtable = +"CREATE TABLE "
    createtable << "IF NOT EXISTS " if if_not_exists
    createtable << self.qualify_table(table)

    partitioned_pks = []
    partitioned_uniques = []
    if partition
      # We cannot use PRIMARY KEY or UNIQUE when partitioning,
      # so set those columns as if they're not
      columns.each_with_index do |c, i|
        if c.pk?
          # Set the type to the serial type as if it's a normal PK
          type = case c.type
            when BIGINT
              :bigserial
            when INTEGER
              :serial
            else
              c.type
          end
          columns[i] = c.change(pk: false, type:)
          partitioned_pks << c
        elsif c.unique?
          columns[i] = c.change(unique: false)
          partitioned_uniques << c
        end
      end
    end
    tbl_lines = columns.map { |c| self.create_column_sql(c) }
    tbl_lines.concat(partitioned_pks.map do |c|
      pkcols = [partition.column, c.name].uniq.join(", ")
      "PRIMARY KEY (#{pkcols})"
    end)
    tbl_lines.concat(partitioned_uniques.map { |c| "UNIQUE (#{partition.column}, #{c.name})" })
    lines = ["#{createtable} ("]
    lines << ("  " + tbl_lines.join(",\n  "))
    lines << ")"
    if partition
      m = case partition.by
        when Webhookdb::DBAdapter::Partitioning::HASH
          "HASH"
        when Webhookdb::DBAdapter::Partitioning::RANGE
          "RANGE"
        else
          raise ArgumentError, "unknown partition method: #{partition.by}"
      end
      lines << "PARTITION BY #{m} (#{partition.column})"
    end
    return lines.join("\n")
  end

  def create_column_sql(column)
    modifiers = +""
    coltype = COLTYPE_MAP.fetch(column.type)
    if column.pk?
      coltype = "bigserial" if column.type == BIGINT
      coltype = "serial" if column.type == INTEGER
      modifiers << " PRIMARY KEY"
    elsif column.unique?
      modifiers << " UNIQUE NOT NULL"
    elsif !column.nullable?
      modifiers << " NOT NULL"
    end
    colname = self.escape_identifier(column.name)
    return "#{colname} #{coltype}#{modifiers}"
  end

  def create_hash_partition_sql(table, partition_count, remainder)
    tbl = self.qualify_table(table)
    s = "CREATE TABLE #{tbl}_#{remainder} PARTITION OF #{tbl} " \
        "FOR VALUES WITH (MODULUS #{partition_count}, REMAINDER #{remainder})"
    return s
  end

  def add_column_sql(table, column, if_not_exists: false)
    c = self.create_column_sql(column)
    ifne = if_not_exists ? " IF NOT EXISTS" : ""
    return "ALTER TABLE #{self.qualify_table(table)} ADD COLUMN#{ifne} #{c}"
  end

  def invalid_indexes_dataset(db, table)
    # SELECT
    #   i.indexrelid::regclass AS index_name,
    #   i.indrelid::regclass  AS table_name,
    #   i.indisvalid,
    #   i.indisready,
    #   i.indisunique,
    #   i.indisprimary,
    #   c2.relname AS index_relname,
    #   n.nspname AS schema_name
    # FROM pg_index i
    # JOIN pg_class c ON i.indrelid = c.oid         -- table
    # JOIN pg_namespace n ON c.relnamespace = n.oid -- schema
    # JOIN pg_class c2 ON i.indexrelid = c2.oid     -- index
    # WHERE n.nspname = 'your_schema'
    #   AND c.relname = 'your_table';
    invalid = db[Sequel[:pg_index].as(:i)].
      join(Sequel[:pg_class].as(:c1), {Sequel[:c1][:oid] => Sequel[:i][:indrelid]}).
      join(Sequel[:pg_namespace].as(:n), {Sequel[:n][:oid] => Sequel[:c1][:relnamespace]}).
      join(Sequel[:pg_class].as(:c2), {Sequel[:c2][:oid] => Sequel[:i][:indexrelid]}).
      select(
        Sequel[:n][:nspname].as(:schema_name),
        Sequel[:i][:indexrelid].cast(:regclass).as(:index_name),
        Sequel[:i][:indrelid].cast(:regclass).as(:table_name),
        Sequel[:i][:indisvalid],
      ).where(
        Sequel[:n][:nspname] => table.schema.name.to_s,
        Sequel[:c1][:relname] => table.name.to_s,
        Sequel[:i][:indisvalid] => false,
      )
    return invalid
  end

  def delete_invalid_indexes(db, table)
    invalid = invalid_indexes_dataset(db, table).all
    invalid.each do |row|
      sch = db.literal(row.fetch(:schema_name).to_sym)
      ind = db.literal(row.fetch(:index_name).to_sym)
      db << "DROP INDEX IF EXISTS #{sch}.#{ind}"
    end
  end

  def select_existing_indexes(db, table)
    return db[:pg_indexes].where(
      schemaname: table.schema.name.to_s,
      tablename: table.name.to_s,
    ).select_map(:indexname)
  end

  # Given a connection, table name (string), and column name (string),
  # get the "last_value" (or 0 if never called) of the sequence for the column.
  def get_serial_sequence_last_value(conn, tablename, colname)
    get_seqname = Sequel.function(:pg_get_serial_sequence, tablename, colname)
    schemaname, sequencename = conn.select(get_seqname.as(:seq)).first.fetch(:seq).split(".")
    last_value = conn[:pg_sequences].where(schemaname:, sequencename:).first.fetch(:last_value)
    return last_value || 0
  end

  def merge_from_csv(connection, file, table, pk_col, copy_columns)
    qtable = self.qualify_table(table)
    temptable = "#{self.escape_identifier(table.name)}_staging_#{SecureRandom.hex(4)}"
    connection.using do |db|
      db << "CREATE TEMP TABLE #{temptable} (LIKE #{qtable})"
      db.copy_into(temptable.to_sym, options: "DELIMITER ',', HEADER true, FORMAT csv", data: file)
      pkname = self.escape_identifier(pk_col.name)
      col_assigns = self.assign_columns_sql("src", nil, copy_columns)
      upsert_sql = [
        <<~UPDATE,
          UPDATE #{qtable} AS tgt
          SET #{col_assigns} FROM
          (SELECT * FROM #{temptable} WHERE #{pkname} IN (SELECT #{pkname} FROM #{qtable})) src
          WHERE tgt.#{pkname} = src.#{pkname};
        UPDATE
        "INSERT INTO #{qtable} SELECT * FROM #{temptable} WHERE #{pkname} NOT IN (SELECT #{pkname} FROM #{qtable});",
      ]
      db << upsert_sql.join("\n")
    end
  end

  def verify_connection(url, timeout: 2, statement: "SELECT 1")
    conn = self.connection(url)
    conn.using(connect_timeout: timeout) do |c|
      c.execute("SET statement_timeout TO #{timeout * 1000}")
      c.execute(statement)
    end
  end

  COLTYPE_MAP = {
    BIGINT => "bigint",
    BIGINT_ARRAY => "bigint[]",
    BOOLEAN => "boolean",
    DATE => "date",
    DECIMAL => "numeric",
    DOUBLE => "double precision",
    FLOAT => "float",
    INTEGER => "integer",
    INTEGER_ARRAY => "integer[]",
    OBJECT => "jsonb",
    TEXT => "text",
    TEXT_ARRAY => "text[]",
    TIMESTAMP => "timestamptz",
    UUID => "uuid",
    :serial => "serial",
    :bigserial => "bigserial",
  }.freeze
end
