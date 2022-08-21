# frozen_string_literal: true

require "pg"

require "webhookdb/db_adapter/default_sql"

class Webhookdb::DBAdapter::PG < Webhookdb::DBAdapter
  include Webhookdb::DBAdapter::ColumnTypes
  include Webhookdb::DBAdapter::DefaultSql

  def identifier_quote_char
    return '"'
  end

  def create_index_sql(index, concurrently:)
    tgts = index.targets.map { |c| self.escape_identifier(c.name) }.join(", ")
    uniq = index.unique ? " UNIQUE" : ""
    concurrent = concurrently ? " CONCURRENTLY" : ""
    idxname = self.escape_identifier(index.name)
    tblname = self.qualify_table(index.table)
    return "CREATE#{uniq} INDEX#{concurrent} IF NOT EXISTS #{idxname} ON #{tblname} (#{tgts})"
  end

  def column_create_sql(column)
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

  def add_column_sql(table, column, if_not_exists: false)
    c = self.column_create_sql(column)
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

  COLTYPE_MAP = {
    BIGINT => "bigint",
    BOOLEAN => "boolean",
    DATE => "date",
    DECIMAL => "numeric",
    DOUBLE => "double precision",
    FLOAT => "float",
    INTEGER => "integer",
    OBJECT => "jsonb",
    TEXT => "text",
    TIMESTAMP => "timestamptz",
  }.freeze
end
