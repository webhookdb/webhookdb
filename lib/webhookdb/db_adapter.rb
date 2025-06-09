# frozen_string_literal: true

class Webhookdb::DBAdapter
  require "webhookdb/db_adapter/column_types"
  require "webhookdb/db_adapter/partition"
  require "webhookdb/db_adapter/partitioning"

  class UnsupportedAdapter < Webhookdb::ProgrammingError; end

  VALID_IDENTIFIER = /^[a-zA-Z][a-zA-Z\d_ ]*$/
  INVALID_IDENTIFIER_PROMPT =
    "Identifiers must start with a letter and contain only letters, numbers, spaces, and underscores.\n" \
    "See https://docs.webhookdb.com/concepts/valid-identifiers/ for rules\n" \
    "about identifiers like schema, table, and column names."

  INVALID_IDENTIFIER_MESSAGE = INVALID_IDENTIFIER_PROMPT.tr("\n", " ")

  class InvalidIdentifier < Webhookdb::InvalidInput; end

  class Schema < Webhookdb::TypedStruct
    attr_reader :name

    def initialize(**kwargs)
      super
      self.typecheck!(:name, Symbol)
    end
  end

  class Table < Webhookdb::TypedStruct
    attr_reader :name, :schema

    def initialize(**kwargs)
      super
      self.typecheck!(:name, Symbol)
      self.typecheck!(:schema, Schema, nullable: true)
    end
  end

  class Column < Webhookdb::TypedStruct
    include ColumnTypes
    attr_reader :name, :type, :nullable, :unique, :index, :index_where, :pk, :backfill_statement, :backfill_expr
    alias nullable? nullable
    alias unique? unique
    alias index? index
    alias pk? pk

    def initialize(**kwargs)
      super
      self.typecheck!(:name, Symbol)
      self.typecheck!(:type, Symbol)
      self.typecheck!(:nullable, :boolean)
      self.typecheck!(:unique, :boolean)
      self.typecheck!(:index, :boolean)
      self.typecheck!(:pk, :boolean)
      raise ArgumentError, "type #{self.type.inspect} is not known" unless COLUMN_TYPES.include?(self.type)
    end

    def _defaults
      return {nullable: true, unique: false, index: false, pk: false}
    end
  end

  class Index < Webhookdb::TypedStruct
    attr_reader :name, :table, :targets, :unique, :where

    def initialize(**kwargs)
      super
      self.typecheck!(:name, Symbol)
      self.typecheck!(:table, Table)
      self.typecheck!(:targets, Array)
      self.typecheck!(:unique, :boolean)
    end

    def _defaults
      return {unique: false}
    end

    # @!attribute name
    #   @return [Symbol]
    # @!attribute table
    #   @return [Table]
    # @!attribute targets
    #   @return [Array<Column>]
    # @!attribute unique
    #   @return [Boolean]
  end

  # Abstract class representing a DB connection.
  # Ususually this is a Sequel connection,
  # but in could just be a stored URL (like for Snowflake
  # we have to call snowsql each time).
  class Connection
    def execute(sql) = raise NotImplementedError
  end

  class SequelConnection < Connection
    include Webhookdb::Dbutil

    def initialize(url)
      super()
      @url = url
    end

    def using(**kw, &)
      borrow_conn(@url, **kw, &)
    end

    def execute(sql, **kw)
      borrow_conn(@url, **kw) do |db|
        db << sql
      end
    end
  end

  # Return a new Connection for the adapter.
  # By default, return a SequelConnection,
  # but adapters not using Sequel will need their own type.
  # @return [Connection]
  def connection(url)
    return SequelConnection.new(url)
  end

  # @param [Schema] schema
  # @param [Boolean] if_not_exists
  # @return [String]
  def create_schema_sql(schema, if_not_exists: false) = raise NotImplementedError

  # Return the CREATE TABLE sql to create table with columns.
  # @param [Table] table
  # @param [Array<Column>] columns
  # @param [Schema] schema
  # @param [TrueClass,FalseClass] if_not_exists If true, use CREATE TABLE IF NOT EXISTS.
  # @param partition [Webhookdb::DBAdapter::Partitioning,nil] If provided,
  #   adds a "PARTITION BY HASH (partition_column_name)" to the returned SQL.
  # @return [String]
  def create_table_sql(table, columns, schema: nil, if_not_exists: false, partition: nil) = raise NotImplementedError

  # We write our own escaper because we want to only escape what's needed;
  # otherwise we want to avoid quoting identifiers.
  def escape_identifier(s) = raise NotImplementedError

  # @param [Index] index
  # @return [String]
  def create_index_sql(index, concurrently:) = raise NotImplementedError

  # Create indices, including for partitions.
  # By default, just call create_index_sql and return it in a single-item array.
  # Override if creating indices while using partitions requires extra logic.
  # @param partitions [Array<Webhookdb::DBAdapter::Partition>]
  # @return [Array<String>]
  def create_index_sqls(index, concurrently:, partitions: [])
    _ = partitions
    return [self.create_index_sql(index, concurrently:)]
  end

  # @param column [Column] The column to create SQL for.
  def create_column_sql(column) = raise NotImplementedError

  # @param [Table] table
  # @param [Column] column
  # @param [Boolean] if_not_exists
  # @return [String]
  def add_column_sql(table, column, if_not_exists: false) = raise NotImplementedError

  # Given a table and a (temporary) file with CSV data,
  # import it into the table. Usually this is a COPY INTO command.
  # For PG it would read from stdin,
  # for Snowflake it would have to stage the file.
  # @param [Connection] connection
  # @param [File] file
  # @param [Table] table
  # @param [Column] pk_col Use this to identifier the same row between source and destination.
  # @param [Array<Column>] copy_columns All columns to copy.
  #   NOTE: This includes the pk column, since it should be copied, as we depend on it persisting.
  def merge_from_csv(connection, file, table, pk_col, copy_columns)= raise NotImplementedError

  def verify_connection(url, timeout: 2, statement: "SELECT 1")
    return self._verify_connection(url, timeout:, statement:)
  end

  # @param [String] url
  # @return [Webhookdb::DBAdapter]
  def self.adapter(url)
    case url
      when /^postgres/
        return Webhookdb::DBAdapter::PG.new
      when /^snowflake/
        return Webhookdb::DBAdapter::Snowflake.new
      else
        msg = "no adapter available for '#{url}'. Must be one of: #{self.supported_adapters_message}"
        raise UnsupportedAdapter, msg
    end
  end

  def self.supported_adapters_message
    return "Postgres (postgres://), SnowflakeDB (snowflake://)"
  end

  def self.valid_identifier?(s) = VALID_IDENTIFIER.match?(s)

  # Raise if the identifier +s+ is invalid according to +VALID_IDENTIFIER+.
  # +type+ is used in the error message, like 'Sorry, this is not a valid table name.'
  # If the user tries SQL injection, let them know we noticed!
  def self.validate_identifier!(s, type:)
    return if self.valid_identifier?(s)
    msg = "Sorry, this is not a valid #{type} name. #{INVALID_IDENTIFIER_MESSAGE}"
    msg += " And we see you what you did there ;)" if s.include?(";") && s.downcase.include?("drop")
    raise InvalidIdentifier, msg
  end
end

require "webhookdb/db_adapter/pg"
require "webhookdb/db_adapter/snowflake"
