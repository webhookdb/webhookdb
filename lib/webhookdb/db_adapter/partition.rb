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

  # Return the partition name for the index.
  # The new index name must fix into +Webhookdb::DBAdapter::MAX_IDENTIFIER_LENGTH+.
  # It will keep any '_idx' (or 3 letter) suffix if present, and then will remove characters from the end.
  # @param [String,Symbol] base_index_name
  # @return [Symbol]
  def index_name(base_index_name)
    base_index_name = base_index_name.to_s
    suffix = self.suffix.to_s
    happy_name = "#{base_index_name}#{suffix}"
    return happy_name.to_sym if happy_name.length <= Webhookdb::DBAdapter::MAX_IDENTIFIER_LENGTH
    if (final_underscore = base_index_name.rindex("_")) && (final_underscore >= (base_index_name.length - 4))
      suffix = base_index_name[final_underscore..] + suffix
    end
    available = Webhookdb::DBAdapter::MAX_IDENTIFIER_LENGTH - suffix.length
    result = base_index_name[...available] + suffix
    raise Webhookdb::InvalidPostcondition, "identifier is too long: #{result.inspect}" if
      result.length > Webhookdb::DBAdapter::MAX_IDENTIFIER_LENGTH
    return result.to_sym
  end
end
