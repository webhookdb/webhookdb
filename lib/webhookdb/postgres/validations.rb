# frozen_string_literal: true

require "webhookdb/postgres"

module Webhookdb::Postgres::Validations
  ### Ensures that only one of the passed columns is not null
  def validates_mutually_exclusive(*cols)
    set_cols = cols.find_all { |col| !self[col].nil? }

    self.errors.add(set_cols.first, "is mutually exclusive with other set columns #{set_cols[1..].join(', ')}") if
        set_cols.length > 1
  end

  ### Ensures that either all of the passed columns are null or none of them are
  def validates_all_or_none(*cols)
    set_cols = cols.find_all { |col| !self[col].nil? }

    self.errors.add(cols.first, "the columns #{cols[1..].join(', ')} must all be set or all be null") if
      !set_cols.empty? && set_cols.length != cols.length
  end

  ### Ensures that at least one of the passed columns is not null
  def validates_at_least_one_of(*cols)
    self.errors.add(cols.first, "must be set if all of #{cols[1..].join(', ')} are null") unless
        cols.any? { |col| !self[col].nil? }
  end

  ### Ensures that one and only one of the passed columns is not null
  def validates_exactly_one_of(*cols)
    self.validates_at_least_one_of(*cols)
    self.validates_mutually_exclusive(*cols)
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
