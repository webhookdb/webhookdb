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

    def self.format(s)
      raise ArgumentError, "#{s} must be a normalized to #{REGEXP}" unless self.valid_normalized?(s)
      return "(#{s[1..3]}) #{s[4..6]}-#{s[7..]}"
    end
  end

  # Given a string representing a phone number, returns that phone number in E.164 format (+1XXX5550100).
  # Assumes all provided phone numbers are US numbers.
  # Does not check for invalid area codes.
  def self.format_e164(phone)
    return nil if phone.blank?
    return phone if /^\+1\d{10}$/.match?(phone)
    phone = phone.gsub(/\D/, "")
    return "+1" + phone if phone.size == 10
    return "+" + phone if phone.size == 11
  end
end
