# frozen_string_literal: true

class Webhookdb::DBAdapter
  require "webhookdb/db_adapter/column_types"

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
    attr_reader :name, :type, :nullable, :unique, :index
    alias nullable? nullable
    alias unique? unique
    alias index? index

    def initialize(**kwargs)
      super
      self.typecheck!(:name, Symbol)
      self.typecheck!(:type, Symbol)
      self.typecheck!(:nullable, :boolean)
      self.typecheck!(:unique, :boolean)
      self.typecheck!(:index, :boolean)
      raise ArgumentError, "type #{self.type.inspect} is not known" unless COLUMN_TYPES.include?(self.type)
    end

    def _defaults
      return {nullable: true, unique: false, index: false}
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
  def create_index_sql(index)
    raise NotImplementedError
  end

  # @param [Table] table
  # @param [Column] column
  # @param [Boolean] if_not_exists
  # @return [String]
  def add_column_sql(table, column, if_not_exists: false)
    raise NotImplementedError
  end

  # @param [String] url
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
