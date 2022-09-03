# frozen_string_literal: true

module Webhookdb::DBAdapter::ColumnTypes
  BIGINT = :bigint
  BOOLEAN = :bool
  DATE = :date
  DECIMAL = :decimal
  DOUBLE = :double
  FLOAT = :float
  INTEGER = :int
  INTEGER_ARRAY = :intarray
  OBJECT = :object
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
      INTEGER_ARRAY,
      OBJECT,
      TEXT,
      TIMESTAMP,
    ],
  )
end
