# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Id
  ID_BYTES = 16

  UUID_RE = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

  def self.new_opaque_id(prefix)
    b36 = self.rand_enc(ID_BYTES)
    return "#{prefix}_#{b36}"
  end

  def self.rand_enc(blen)
    b = SecureRandom.bytes(blen)
    return Digest.hexencode(b).to_i(16).to_s(36)
  end
end
