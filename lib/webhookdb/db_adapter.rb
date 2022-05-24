# frozen_string_literal: true

class Webhookdb::DBAdapter
  module ColumnTypes
    BIGINT = :bigint
    BOOLEAN = :bool
    DATE = :date
    DECIMAL = :decimal
    DOUBLE = :double
    FLOAT = :float
    INTEGER = :int
    OBJECT = :object
    PKEY = :pk
    TEXT = :text
    TIMESTAMP = :timestamp

    COLUMN_TYPES = Set.new(
      [
        BIGINT,
        BOOLEAN,
        DATE,
        DECIMAL,
        DOUBLE,
        FLOAT,
        INTEGER,
        OBJECT,
        PKEY,
        TEXT,
        TIMESTAMP,
      ],
    )
  end

  class Table < Webhookdb::TypedStruct
    attr_reader :name
  end

  class Column < Webhookdb::TypedStruct
    include ColumnTypes
    attr_reader :name, :type, :nullable, :unique, :index
    alias nullable? nullable
    alias unique? unique
    alias index? index

    def initialize(**kwargs)
      super
      raise ArgumentError, "name must be a symbol" unless self.name.is_a?(Symbol)
      raise ArgumentError, "type #{self.type.inspect} is not known" unless COLUMN_TYPES.include?(self.type)
    end

    def _defaults
      return {nullable: true, unique: false, index: false}
    end
  end

  class Index < Webhookdb::TypedStruct
    attr_reader :name, :table, :targets, :unique
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

    # @!attribute table
    #   @return [Table]
    # @!attribute columns
    #   @return [Array<Column>]
    # @!attribute indices
    #   @return [Array<Index>]

    def _defaults
      return {indices: [], columns: []}
    end
  end

  # @param [Table] table
  # @param [Array<Column>] columns
  # @return [String]
  def create_table_sql(table, columns); end

  # @param [Index] index
  # @return [String]
  def create_index_sql(index)
    raise NotImplementedError
  end

  # @param [Table] table
  # @param [Column] column
  # @return [String]
  def add_column_sql(table, column)
    raise NotImplementedError
  end

  # @return [Webhookdb::DBAdapter]
  def self.adapter(url)
    case url
      when /^postgres/
        return Webhookdb::DBAdapter::PG.new
      else
        raise ArgumentError, "no adapter available for #{url}"
    end
  end
end

require "webhookdb/db_adapter/pg"
