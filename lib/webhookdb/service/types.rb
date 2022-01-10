# frozen_string_literal: true

require "grape"

module Webhookdb::Service::Types
  def self.included(ctx)
    ctx.const_set(:NormalizedEmail, NormalizedEmail)
    ctx.const_set(:NormalizedPhone, NormalizedPhone)
    ctx.const_set(:CommaSepArray, CommaSepArray)
  end

  class NormalizedEmail
    def self.parse(value)
      return value.downcase.strip
    end
  end

  class NormalizedPhone
    def self.parse(value)
      return Webhookdb::PhoneNumber::US.normalize(value)
    end
  end

  class CommaSepArray
    def self.parse(value)
      return value.split(",").map(&:strip)
    end
  end
end
