# frozen_string_literal: true

class Webhookdb::Services::Column
  # @return [Symbol]
  attr_reader :name
  # @return [String]
  attr_reader :type
  # @return [String]
  attr_reader :modifiers

  def initialize(name, type, modifiers=nil)
    raise ArgumentError, "name must be a symbol" unless name.is_a?(Symbol)
    raise ArgumentError, "type must be a string" unless type.is_a?(String)
    raise ArgumentError, "modifiers must be a string" unless modifiers.nil? || modifiers.is_a?(String)
    @name = name
    @type = type
    @modifiers = modifiers || ""
  end
end
