# frozen_string_literal: true

module Webhookdb::Formatting
  TABLE = "table"
  OBJECT = "object"
  FORMATS = [TABLE, OBJECT].freeze

  def self.validate!(fmt)
    raise ArgumentError, "'#{fmt}' is not a valid format" unless fmt.in?(FORMATS)
  end

  def self.blocks
    return Blocks.new
  end

  class Blocks
    def initialize
      @arr = []
    end

    def blank
      return self.line("")
    end

    def line(value)
      @arr << Line.new(value)
      return self
    end

    def table(headers, rows)
      @arr << Table.new(headers, rows)
      return self
    end

    def as_json(*a)
      return @arr.as_json(*a)
    end
  end

  class Line
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def as_json(*)
      return {type: "line", value: self.value}
    end
  end

  class Table
    attr_accessor :headers, :rows

    def initialize(headers, rows)
      @headers = headers
      @rows = rows
    end

    def as_json(*o)
      return {type: "table", value: {headers: self.headers, rows: self.rows.as_json(*o)}}
    end
  end
end
