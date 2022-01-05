# frozen_string_literal: true

module Webhookdb::PhoneNumber
  class US
    REGEXP = /^1[0-9]{10}$/

    def self.normalize(s)
      norm = Phony.normalize(s, cc: "1")
      norm = "1#{norm}" if norm.length == 10 && norm.first == "1"
      return norm
    end

    def self.valid?(s)
      return false if s.nil?
      return self.valid_normalized?(self.normalize(s))
    end

    def self.valid_normalized?(s)
      return REGEXP.match?(s)
    end
  end
end
