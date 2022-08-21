# frozen_string_literal: true

class Webhookdb::DBAdapter
  require "webhookdb/db_adapter/column_types"

  class UnsupportedAdapter < RuntimeError; end

  VALID_IDENTIFIER = /^[a-zA-Z][a-zA-Z\d_ ]*$/
  INVALID_IDENTIFIER_MESSAGE = "Identifiers must start with a letter and " \
                               "contain only letters, numbers, spaces, and underscores. " \
                               "See https://webhookdb.com/docs/cli#db-identifiers for rules " \
                               "about identifiers like schema, table, and column names."

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
    attr_reader :name, :type, :nullable, :unique, :index, :pk
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
    attr_reader :name, :table, :targets, :unique

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

  class TableDescriptor < Webhookdb::TypedStruct
    attr_reader :table, :columns, :indices

    def initialize(**kwargs)
      super
      self.typecheck!(:table, Table)
      self.typecheck!(:columns, Array)
      self.typecheck!(:indices, Array)
    end

    # @!attribute table
    #   @return [Table]
    # @!attribute columns
    #   @return [Array<Column>]
    # @!attribute indices
    #   @return [Array<Index>]

    def _defaults
      return {indices: []}
    end
  end

  # Abstract class representing a DB connection.
  # Ususually this is a Sequel connection,
  # but in could just be a stored URL (like for Snowflake
  # we have to call snowsql each time).
  class Connection
    def execute(sql)
      raise NotImplementedError
    end
  end

  class SequelConnection < Connection
    include Webhookdb::Dbutil

    def initialize(url)
      super()
      @url = url
    end

    def using(&)
      borrow_conn(@url, &)
    end

    def execute(sql)
      borrow_conn(@url) do |db|
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
  def create_schema_sql(schema, if_not_exists: false)
    raise NotImplementedError
  end

  # @param [Table] table
  # @param [Array<Column>] columns
  # @param [Schema] schema
  # @param [Boolean] if_not_exists
  # @return [String]
  def create_table_sql(table, columns, schema: nil, if_not_exists: false)
    raise NotImplementedError
  end

  # @param [Index] index
  # @return [String]
  def create_index_sql(index, concurrently:)
    raise NotImplementedError
  end

  # @param [Table] table
  # @param [Column] column
  # @param [Boolean] if_not_exists
  # @return [String]
  def add_column_sql(table, column, if_not_exists: false)
    raise NotImplementedError
  end

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
  def merge_from_csv(connection, file, table, pk_col, copy_columns)
    raise NotImplementedError
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
        raise UnsupportedAdapter, "no adapter available for #{url}"
    end
  end

  def self.supported_adapters_message
    return "Postgres (postgres://), SnowflakeDB (snowflake://)"
  end
end

require "webhookdb/db_adapter/pg"
require "webhookdb/db_adapter/snowflake"
