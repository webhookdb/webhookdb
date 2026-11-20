# frozen_string_literal: true

require "grape"

module Webhookdb::Service::Types
  def self.included(ctx)
    ctx.const_set(:NormalizedEmail, NormalizedEmail)
    ctx.const_set(:NormalizedPhone, NormalizedPhone)
    ctx.const_set(:CommaSepArray, CommaSepArray)
    ctx.const_set(:TrimmedString, TrimmedString)
  end

  class NormalizedEmail < String
    def self.parse(value) = self.new(value.downcase.strip)
  end

  class NormalizedPhone < String
    def self.parse(value) = self.new(Webhookdb::PhoneNumber::US.normalize(value))
  end

  class TrimmedString < String
    def self.parse(value) = self.new(value.strip)
    def self.map(arr) = arr.map { |a| self.new(a) }
  end

  class CommaSepArray
    def self.parse(value)
      return value if value.respond_to?(:to_ary)
      return value.split(",").map(&:strip)
    end
  end
end
