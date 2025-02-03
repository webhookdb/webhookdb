# frozen_string_literal: true

class Webhookdb::DBAdapter::Partition < Webhookdb::TypedStruct
  attr_reader :parent_table, :partition_name, :suffix

  def initialize(**kwargs)
    super
    self.typecheck!(:parent_table, Webhookdb::DBAdapter::Table)
    self.typecheck!(:partition_name, Symbol)
    self.typecheck!(:suffix, Symbol)
  end

  def partition_table = Webhookdb::DBAdapter::Table.new(name: self.partition_name, schema: self.parent_table.schema)
end
