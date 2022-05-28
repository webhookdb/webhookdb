# frozen_string_literal: true

module Webhookdb::DBAdapter::ColumnTypes
  BIGINT = :bigint
  BOOLEAN = :bool
  DATE = :date
  DECIMAL = :decimal
  DOUBLE = :double
  FLOAT = :float
  INTEGER = :int
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
      OBJECT,
      TEXT,
      TIMESTAMP,
    ],
  )
end
