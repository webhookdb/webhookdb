# frozen_string_literal: true

require "pg"

class Webhookdb::DBAdapter::PG < Webhookdb::DBAdapter
  include Webhookdb::DBAdapter::ColumnTypes

  def create_table_sql(table, columns)
    lines = [
      "CREATE TABLE #{self._escape_identifier(table.name)} (",
    ]
    columns[0...-1]&.each { |c| lines << "  #{self.column_create_sql(c)}," }
    lines << "  #{self.column_create_sql(columns.last)}"
    lines << ")"
    return lines.join("\n")
  end

  def create_index_sql(index)
    tgts = index.targets.map { |c| self._escape_identifier(c.name) }.join(", ")
    uniq = index.unique ? " UNIQUE" : ""
    idxname = self._escape_identifier(index.name)
    tblname = self._escape_identifier(index.table.name)
    return "CREATE#{uniq} INDEX IF NOT EXISTS #{idxname} ON #{tblname} (#{tgts})"
  end

  def column_create_sql(column)
    modifiers = +""
    if column.type == PKEY
      modifiers << " PRIMARY KEY"
    elsif column.unique?
      modifiers << " UNIQUE NOT NULL"
    elsif !column.nullable?
      modifiers << " NOT NULL"
    end
    coltype = COLTYPE_MAP.fetch(column.type)
    colname = self._escape_identifier(column.name)
    return "#{colname} #{coltype}#{modifiers}"
  end

  def add_column_sql(table, column)
    c = self.column_create_sql(column)
    tblname = self._escape_identifier(table.name)
    return "ALTER TABLE #{tblname} ADD #{c}"
  end

  # We write our own escaper because we want to only escape what's needed;
  # otherwise we want to avoid quoting identifiers.
  def _escape_identifier(s)
    s = s.to_s
    return "\"#{s}\"" if RESERVED_KEYWORDS.include?(s.upcase)
    raise ArgumentError, "identifier #{s.inspect} cannot contain spaces" if /\s/.match?(s)
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
    PKEY => "bigserial",
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
