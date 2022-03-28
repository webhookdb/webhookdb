# frozen_string_literal: true

class Webhookdb::Services::Column
  # @return [Symbol]
  attr_reader :name
  # @return [String]
  attr_reader :type
  # @return [Boolean]
  attr_reader :index
  alias index? index

  def initialize(name, type, index: false)
    raise ArgumentError, "name must be a symbol" unless name.is_a?(Symbol)
    raise ArgumentError, "type must be a string" unless type.is_a?(String)
    @name = name
    @type = type
    @index = index
  end

  # Modifier string for a column, like 'NOT NULL', etc.
  # @return [String]
  def modifiers
    return ""
  end
end
