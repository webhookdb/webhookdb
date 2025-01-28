# frozen_string_literal: true

module Webhookdb::DBAdapter::DefaultSql
  def create_schema_sql(schema, if_not_exists: false)
    s = +"CREATE SCHEMA "
    s << "IF NOT EXISTS " if if_not_exists
    s << self.escape_identifier(schema.name)
    return s
  end

  def identifier_quote_char
    raise NotImplementedError
  end

  # We write our own escaper because we want to only escape what's needed;
  # otherwise we want to avoid quoting identifiers.
  def escape_identifier(s)
    s = s.to_s
    raise ArgumentError, "#{s} is an invalid identifier and should have been validated previously" unless
      Webhookdb::DBAdapter.valid_identifier?(s)

    quo = self.identifier_quote_char
    return "#{quo}#{s}#{quo}" if RESERVED_KEYWORDS.include?(s.upcase) ||
      s.include?(" ") ||
      s.include?("-") ||
      s.start_with?(/\d/)
    return s
  end

  # @param [Webhookdb::DBAdapter::Table] table
  def qualify_table(table)
    s = +""
    if table.schema
      s << self.escape_identifier(table.schema.name)
      s << "."
    end
    s << self.escape_identifier(table.name)
    return s
  end

  # Return the SQL string for column assignment.
  # Like for src and dest of :src and :tgt,
  # and columns with names :spam and :foo,
  # return "tgt.spam = src.spam, tgt.foo = src.foo"
  # Column names will be escaped; the source and destination values
  # should already be valid identifiers (usually aliases for a table or query).
  #
  # If a block is given, call it with (column, left hand side string, right hand side string).
  # It should return the new lhs/rhs strings.
  #
  # @param [String, nil] source Prefix (like table alias) for right hand side columns.
  # @param [String, nil] destination nil Prefix (like table alias) for left hand side columns.
  # @param [Array<Webhookdb::DBAdapter::Column>] columns
  def assign_columns_sql(source, destination, columns, &block)
    stmts = columns.map do |c|
      cname = self.escape_identifier(c.name)
      lhs = destination ? "#{destination}.#{cname}" : cname
      rhs = source ? "#{source}.#{cname}" : cname
      lhs, rhs = block[c, lhs, rhs] if block
      "#{lhs} = #{rhs}"
    end
    return stmts.join(", ")
  end

  # These are all PG reserved keywords, as per https://www.postgresql.org/docs/current/sql-keywords-appendix.html
  PG_RESERVED_KEYWORDS = Set.new(
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

  # Reserved keywords must be quoted to be used as identifiers.
  RESERVED_KEYWORDS = PG_RESERVED_KEYWORDS
end
