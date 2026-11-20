# frozen_string_literal: true

class Webhookdb::DBAdapter::Partitioning < Webhookdb::TypedStruct
  HASH = :hash
  RANGE = :range

  attr_reader :by, :column
end
