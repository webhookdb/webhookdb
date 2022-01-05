# frozen_string_literal: true

require "webhookdb/postgres"

module Webhookdb::Postgres::Validations
  # Ensures that only one of the passed columns is not nil.
  def validates_mutually_exclusive(*cols, predicate: :nil?)
    truthy_cols = cols.find_all { |col| !self[col].send(predicate) }
    multiple_set = truthy_cols.length > 1
    return unless multiple_set
    self.errors.add(truthy_cols.first, "is mutually exclusive with other set columns #{truthy_cols[1..].join(', ')}")
  end

  # Ensures that either all of the passed columns are nil or none of them are.
  def validates_all_or_none(*cols, predicate: :nil?)
    truthy_cols = cols.find_all { |col| !self[col].send(predicate) }

    return if truthy_cols.empty? || truthy_cols.length == cols.length

    msg = "the columns #{cols[1..].join(', ')} must all be set or all be #{predicate.to_s.delete_suffix('?')}"
    self.errors.add(cols.first, msg)
  end

  # Ensures that at least one of the passed columns is not nil.
  def validates_at_least_one_of(*cols, predicate: :nil?)
    any_truthy = cols.any? { |col| !self[col].send(predicate) }
    return if any_truthy
    msg = "at least one of #{cols.join(', ')} must be not #{predicate.to_s.delete_suffix('?')}"
    self.errors.add(cols.first, msg)
  end

  # Ensures that one and only one of the passed columns is not nil.
  def validates_exactly_one_of(*cols, predicate: :nil?)
    self.validates_at_least_one_of(*cols, predicate: predicate)
    self.validates_mutually_exclusive(*cols, predicate: predicate)
  end

  def validates_ip_address(col)
    return if self[col].respond_to?(:ipv4?)
    begin
      IPAddr.new(self[col])
    rescue IPAddr::Error
      self.errors.add(col, "is not a valid INET address")
    end
  end
end
