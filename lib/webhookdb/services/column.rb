# frozen_string_literal: true

require "webhookdb/db_adapter"

class Webhookdb::Services::Column
  include Webhookdb::DBAdapter::ColumnTypes

  # @return [Symbol]
  attr_reader :name
  # @return [Symbol]
  attr_reader :type
  # @return [Boolean]
  attr_reader :index
  alias index? index

  def initialize(name, type, index: false)
    raise ArgumentError, "name must be a symbol" unless name.is_a?(Symbol)
    raise ArgumentError, "type #{type.inspect} is not supported" unless COLUMN_TYPES.include?(type)
    @name = name
    @type = type
    @index = index
  end

  def to_dbadapter(**more)
    kw = {name: self.name, type: self.type, index: self.index}
    kw.merge!(more)
    return Webhookdb::DBAdapter::Column.new(**kw)
  end
end
