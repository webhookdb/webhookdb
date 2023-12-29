# frozen_string_literal: true

module Webhookdb::DBAdapter::ColumnTypes
  BIGINT = :bigint
  BIGINT_ARRAY = :bigintarray
  BOOLEAN = :bool
  DATE = :date
  DECIMAL = :decimal
  DOUBLE = :double
  FLOAT = :float
  INTEGER = :int
  INTEGER_ARRAY = :intarray
  TEXT_ARRAY = :textarray
  OBJECT = :object
  TEXT = :text
  TIMESTAMP = :timestamp
  UUID = :uuid

  COLUMN_TYPES = Set.new(
    [
      BIGINT,
      BIGINT_ARRAY,
      BOOLEAN,
      DATE,
      DECIMAL,
      DOUBLE,
      FLOAT,
      INTEGER,
      INTEGER_ARRAY,
      OBJECT,
      TEXT,
      TEXT_ARRAY,
      TIMESTAMP,
      UUID,
    ],
  )
end
