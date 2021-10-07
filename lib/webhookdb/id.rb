# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Id
  ID_BYTES = 16

  def self.new_opaque_id(prefix)
    b = SecureRandom.bytes(ID_BYTES)
    b36 = Digest.hexencode(b).to_i(16).to_s(36)
    return "#{prefix}_#{b36}"
  end
end
