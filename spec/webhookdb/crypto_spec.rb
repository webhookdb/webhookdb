# frozen_string_literal: true

require "webhookdb/crypto"

RSpec.describe Webhookdb::Crypto do
  it "can encrypt and decrypt strings" do
    key = described_class::Boxed.from_b64("6vHQcB8xlVSmHO2Wxsqk713k7oi_SpIWirUG0YTGUa4=")
    value = described_class::Boxed.from_raw("hello Boom")
    enc = described_class.encrypt_value(key, value)
    expect(enc.base64).to eq("mzre1LavjI7wUWdZRsYsUA==")
    dec = described_class.decrypt_value(key, enc)
    expect(dec.raw).to eq("hello Boom")
    expect(dec.base64).to eq("aGVsbG8gQm9vbQ==")
  end

  it "can generate a random encryption key" do
    k1 = described_class.encryption_key.base64
    k2 = described_class.encryption_key.base64
    expect(k1).to_not eq(k2)
  end
end
