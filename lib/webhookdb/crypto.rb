# frozen_string_literal: true

module Webhookdb::Crypto
  CIPHER = OpenSSL::Cipher.new("aes-256-cbc")

  # @return [Boxed]
  def self.encryption_key
    k = CIPHER.encrypt.random_key
    return Boxed.from_raw(k)
  end

  # @param key [Boxed]
  # @param value [Boxed]
  # @return [Boxed]
  def self.encrypt_value(key, value)
    cipher = CIPHER.encrypt
    cipher.key = key.raw
    enc = cipher.update(value.raw) + cipher.final
    return Boxed.from_raw(enc)
  end

  # @param key [Boxed]
  # @param value [Boxed]
  # @return [Boxed]
  def self.decrypt_value(key, value)
    cipher = CIPHER.decrypt
    cipher.key = key.raw
    dec = cipher.update(value.raw) + cipher.final
    return Boxed.from_raw(dec)
  end

  class Boxed
    def self.from_raw(bytestr)
      return self.new(bytestr, nil)
    end

    def self.from_b64(b64str)
      return self.new(nil, b64str)
    end

    def initialize(raw, b64)
      @raw = raw
      @b64 = b64
    end

    # @return [String]
    def base64
      @b64 ||= Base64.urlsafe_encode64(@raw)
      return @b64
    end

    # @return [String]
    def raw
      @raw ||= Base64.urlsafe_decode64(@b64)
      return @raw
    end
  end
end
