# frozen_string_literal: true

RSpec.describe "helpers", :integration do
  it "can use the redis cache" do
    key = "integration-test-key"
    Webhookdb::Redis.cache.with do |r|
      r.call("SET", key, "1")
      expect(r.call("GET", key)).to eq("1")
    end
    t = Thread.start do
      Webhookdb::Redis.cache.with do |r|
        r.call("DEL", key)
        expect(r.call("GET", key)).to be_nil
      end
    end
    t.join
    Webhookdb::Redis.cache.with do |r|
      expect(r.call("GET", key)).to be_nil
    end
  end
end
