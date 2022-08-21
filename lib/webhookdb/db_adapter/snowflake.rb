# frozen_string_literal: true

require "webhookdb/db_adapter/default_sql"
require "webhookdb/snowflake"

class Webhookdb::DBAdapter::Snowflake < Webhookdb::DBAdapter
  include Webhookdb::DBAdapter::ColumnTypes
  include Webhookdb::DBAdapter::DefaultSql

  class SnowsqlConnection < Webhookdb::DBAdapter::Connection
    include Appydays::Loggable

    def initialize(url)
      super()
      @url = url
    end

    def execute(sql, **opts)
      self.logger.debug("snowflake_exec", statement: sql)
      result = Webhookdb::Snowflake.run_cli(@url, sql, **opts)
      self.logger.debug("snowflake_exec_result", result:)
      return result
    end
  end

  def connection(url)
    return SnowsqlConnection.new(url)
  end

  def create_index_sql(*)
    raise NotImplementedError, "Snowflake does not support indices"
  end

  def column_create_sql(column)
    modifiers = +""
    if column.unique?
      modifiers << " UNIQUE NOT NULL"
    elsif !column.nullable?
      modifiers << " NOT NULL"
    end
    coltype = COLTYPE_MAP.fetch(column.type)
    colname = self.escape_identifier(column.name)
    return "#{colname} #{coltype}#{modifiers}"
  end

  def add_column_sql(table, column, if_not_exists: false)
    c = self.column_create_sql(column)
    # Snowflake has no 'ADD COLUMN IF NOT EXISTS' so we need to query the long way around
    add_sql = "ALTER TABLE #{self.qualify_table(table)} ADD COLUMN #{c}"
    return add_sql unless if_not_exists
    # The 'ILIKE' is a case-insensitive string compare,
    # which is important because snowflake uppercases values when it stores them.
    conditional_sql = <<~SQL
      EXECUTE IMMEDIATE $$
      BEGIN
        IF (NOT EXISTS(
          SELECT * FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA ILIKE '#{table.schema.name}'
            AND TABLE_NAME ILIKE '#{table.name}'
            AND COLUMN_NAME ILIKE '#{column.name}'
        )) THEN
          #{add_sql};
        END IF;
      END;
      $$
    SQL
    return conditional_sql.rstrip
  end

  def merge_from_csv(connection, file, table, pk_col, copy_columns)
    raise Webhookdb::InvalidPrecondition, "table must have schema" if table.schema.nil?

    qtable = self.qualify_table(table)

    stage = self.escape_identifier("whdb_tempstage_#{SecureRandom.hex(2)}_#{table.name}")
    stage = self.escape_identifier(table.schema.name) + "." + stage

    pkname = self.escape_identifier(pk_col.name)
    # JSON columns need to be parsed from the CSV, so object columns need parse_json calls.
    col_assigns = self.assign_columns_sql("src", nil, copy_columns) do |c, lhs, rhs|
      if c.type == OBJECT
        [lhs, "parse_json(#{rhs})"]
      else
        [lhs, rhs]
      end
    end
    col_names = copy_columns.map { |c| self.escape_identifier(c.name) }
    col_values = col_names.each_with_index.map do |n, i|
      if copy_columns[i].type == OBJECT
        "parse_json(src.#{n})"
      else
        "src.#{n}"
      end
    end
    col_placeholders = col_names.each_with_index.map { |n, i| "$#{i + 1} #{n}" }
    # Props to https://stackoverflow.com/questions/63084511/snowflake-upsert-from-staged-files
    # for the merge from stage code.
    # The enclosed option is vital because otherwise it doesn't interpret JSON columns properly.
    import_sql = <<~SQL
      CREATE STAGE #{stage} FILE_FORMAT = (type = 'CSV' skip_header = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

      PUT file://#{file.path} @#{stage} auto_compress=true;

      MERGE INTO #{qtable} AS tgt
        USING (
          SELECT #{col_placeholders.join(', ')} FROM @#{stage}
        ) src
        ON tgt.#{pkname} = src.#{pkname}
        WHEN MATCHED THEN UPDATE SET #{col_assigns}
        WHEN NOT MATCHED THEN INSERT (#{col_names.join(', ')}) values (#{col_values.join(', ')});
    SQL
    connection.execute(import_sql)
  end

  def identifier_quote_char
    return ""
  end

  COLTYPE_MAP = {
    BIGINT => "bigint",
    BOOLEAN => "boolean",
    DATE => "date",
    DECIMAL => "numeric",
    DOUBLE => "double precision",
    FLOAT => "float",
    INTEGER => "integer",
    OBJECT => "object",
    TEXT => "text",
    TIMESTAMP => "timestamptz",
  }.freeze
end
