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
