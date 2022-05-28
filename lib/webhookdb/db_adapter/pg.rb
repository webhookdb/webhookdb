# frozen_string_literal: true

require "pg"

class Webhookdb::DBAdapter::PG < Webhookdb::DBAdapter
  include Webhookdb::DBAdapter::ColumnTypes

  def create_schema_sql(schema, if_not_exists: false)
    s = +"CREATE SCHEMA "
    s << "IF NOT EXISTS " if if_not_exists
    s << self._escape_identifier(schema.name)
    return s
  end

  def create_table_sql(table, columns, if_not_exists: false)
    createtable = +"CREATE TABLE "
    createtable << "IF NOT EXISTS " if if_not_exists
    createtable << self._qualify_table(table)
    lines = ["#{createtable} ("]
    columns[0...-1]&.each { |c| lines << "  #{self.column_create_sql(c)}," }
    lines << "  #{self.column_create_sql(columns.last)}"
    lines << ")"
    return lines.join("\n")
  end

  def create_index_sql(index)
    tgts = index.targets.map { |c| self._escape_identifier(c.name) }.join(", ")
    uniq = index.unique ? " UNIQUE" : ""
    idxname = self._escape_identifier(index.name)
    tblname = self._qualify_table(index.table)
    return "CREATE#{uniq} INDEX IF NOT EXISTS #{idxname} ON #{tblname} (#{tgts})"
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
    colname = self._escape_identifier(column.name)
    return "#{colname} #{coltype}#{modifiers}"
  end

  def add_column_sql(table, column, if_not_exists: false)
    c = self.column_create_sql(column)
    ifne = if_not_exists ? " IF NOT EXISTS" : ""
    return "ALTER TABLE #{self._qualify_table(table)} ADD COLUMN#{ifne} #{c}"
  end

  def merge_from_csv(db, table, file)
    qtable = self._qualify_table(table)
    temptable = "#{self._escape_identifier(table.name)}_staging_#{SecureRandom.hex(4)}"
    db << "CREATE TEMP TABLE #{temptable} (LIKE #{self._qualify_table(table)})"
    db.copy_into(temptable.to_sym, format: :csv, data: file)
    db << "INSERT INTO #{qtable} SELECT * FROM #{temptable} WHERE pk NOT IN (SELECT pk FROM #{qtable})"
    db << "UPDATE #{qtable} AS tgt SET at = src.at FROM " \
          "(SELECT * FROM #{temptable} WHERE pk IN (SELECT pk FROM #{qtable})) src"
  end

  def _qualify_table(table)
    s = +""
    if table.schema
      s << self._escape_identifier(table.schema.name)
      s << "."
    end
    s << self._escape_identifier(table.name)
    return s
  end

  # We write our own escaper because we want to only escape what's needed;
  # otherwise we want to avoid quoting identifiers.
  def _escape_identifier(s)
    s = s.to_s
    return "\"#{s}\"" if RESERVED_KEYWORDS.include?(s.upcase)
    raise ArgumentError, "identifier #{s.inspect} cannot contain spaces or semicolons" if
      /\s/.match?(s) || s.include?(";")
    return s
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

  # These are all PG reserved keywords, as per https://www.postgresql.org/docs/current/sql-keywords-appendix.html
  # They cannot be used as identifiers.
  RESERVED_KEYWORDS = Set.new(
    [
      "ALL",
      "ANALYSE",
      "ANALYZE",
      "AND",
      "ANY",
      "ARRAY",
      "AS",
      "ASC",
      "ASYMMETRIC",
      "AUTHORIZATION",
      "BINARY",
      "BOTH",
      "CASE",
      "CAST",
      "CHECK",
      "COLLATE",
      "COLLATION",
      "COLUMN",
      "CONCURRENTLY",
      "CONSTRAINT",
      "CREATE",
      "CROSS",
      "CURRENT_CATALOG",
      "CURRENT_DATE",
      "CURRENT_ROLE",
      "CURRENT_SCHEMA",
      "CURRENT_TIME",
      "CURRENT_TIMESTAMP",
      "CURRENT_USER",
      "DECODE",
      "DEFAULT",
      "DEFERRABLE",
      "DESC",
      "DISTINCT",
      "DISTRIBUTED",
      "DO",
      "ELSE",
      "END",
      "EXCEPT",
      "FALSE",
      "FETCH",
      "FOR",
      "FOREIGN",
      "FREEZE",
      "FROM",
      "FULL",
      "GRANT",
      "GROUP",
      "HAVING",
      "ILIKE",
      "IN",
      "INITIALLY",
      "INNER",
      "INTERSECT",
      "INTO",
      "IS",
      "ISNULL",
      "JOIN",
      "LATERAL",
      "LEADING",
      "LEFT",
      "LIKE",
      "LIMIT",
      "LOCALTIME",
      "LOCALTIMESTAMP",
      "LOG",
      "NATURAL",
      "NOT",
      "NOTNULL",
      "NULL",
      "OFFSET",
      "ON",
      "ONLY",
      "OR",
      "ORDER",
      "OUTER",
      "OVERLAPS",
      "PLACING",
      "PRIMARY",
      "REFERENCES",
      "RETURNING",
      "RIGHT",
      "SCATTER",
      "SELECT",
      "SESSION_USER",
      "SIMILAR",
      "SOME",
      "SYMMETRIC",
      "TABLE",
      "THEN",
      "TO",
      "TRAILING",
      "TRUE",
      "UNION",
      "UNIQUE",
      "USER",
      "USING",
      "VARIADIC",
      "VERBOSE",
      "WHEN",
      "WHERE",
      "WINDOW",
      "WITH",
    ],
  )
end
