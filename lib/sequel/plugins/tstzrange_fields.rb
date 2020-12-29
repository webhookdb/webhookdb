# frozen_string_literal: true

require "sequel"
require "sequel/model"

# Plugin for adding methods for working with time ranges.
#
# == Example
#
# Defining a model class with a timestamptz range:
#
#   class ACME::Lease < Sequel::Model(:leases)
#       plugin :tstzrange_fields, :active_during
#
# And in the schema:
#
#   create_table(:leases) do
#       primary_key :id
#       tstzrange :active_during
#   end
#
# You can use it as follows:
#
#   lease = ACME::Lease.new
#   lease.active_during_begin = Time.now
#   lease.active_during_end = 1.year.from_now
#   lease.active_during = 1.year.ago..1.year.from_now
#   lease.active_during_end = nil # Unbounded end set
#   lease.active_during = nil # Empty set
#
module Sequel::Plugins::TstzrangeFields
  def self.configure(model, *args)
    args << :period if args.empty?
    args = args.flatten

    self.setup_model(model)

    args.flatten.each do |column|
      self.create_accessors(model, column)
    end
  end

  def self.setup_model(model)
    model.class.define_method(:new_tstzrange) do |b, e|
      b = self.value_to_time(b)
      e = self.value_to_time(e)
      return Sequel::Postgres::PGRange.empty(:tstzrange) if b.nil? && e.nil?
      return Sequel::Postgres::PGRange.new(b&.to_time, e&.to_time, db_type: :tstzrange, exclude_end: true)
    end

    model.class.define_method(:value_to_time) do |v|
      return v if v.nil?
      return v if v.respond_to?(:to_time)
      return Time.parse(v)
    end
  end

  def self.create_accessors(model, column)
    get_column_method = column.to_sym
    set_column_method = "#{column}=".to_sym
    get_begin_method = "#{column}_begin".to_sym
    set_begin_method = "#{column}_begin=".to_sym
    get_end_method = "#{column}_end".to_sym
    set_end_method = "#{column}_end=".to_sym

    model.define_method(get_column_method) do
      self[column]
    end

    model.define_method(set_column_method) do |value|
      case value
        when Sequel::Postgres::PGRange
          self[column] = value
        when Float::INFINITY
          range = Sequel::Postgres::PGRange.new(nil, nil, empty: false, db_type: :tstzrange)
          self[column] = range
        when "empty"
          self[column] = Sequel::Postgres::PGRange.empty(:tstzrange)
      else
          beg = value.respond_to?(:begin) ? value.begin : (value[:begin] || value["begin"])
          en = value.respond_to?(:end) ? value.end : (value[:end] || value["end"])
          self[column] = self.class.new_tstzrange(beg, en)
      end
    end

    model.define_method(get_begin_method) do
      self.send(get_column_method).begin
    end

    model.define_method(set_begin_method) do |new_time|
      new_range = self.class.new_tstzrange(new_time, self.send(get_end_method))
      self.send(set_column_method, new_range)
    end

    model.define_method(get_end_method) do
      r = self.send(get_column_method)
      return r.nil? ? nil : r.end # &.end is invalid syntax
    end

    model.define_method(set_end_method) do |new_time|
      new_range = self.class.new_tstzrange(self.send(get_begin_method), new_time)
      self.send(set_column_method, new_range)
    end
  end
end
