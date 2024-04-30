# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator::WebhookRequest do
  describe "as_json" do
    it "does not include a Rack Request" do
      w = described_class.new
      expect(w.as_json).to eq({})

      w = described_class.new(body: "x", headers: {"X" => "1"}, path: "/a", method: :GET)
      expect(w.as_json).to eq({"body" => "x", "headers" => {"X" => "1"}, "method" => "GET", "path" => "/a"})

      w.rack_request = Rack::Request.new({})
      expect(w.as_json).to eq({"body" => "x", "headers" => {"X" => "1"}, "method" => "GET", "path" => "/a"})

      # Create an invalid env to make sure it doesn't even attempt to serialize.
      env = {x: 1}
      env[:y] = env
      w.rack_request = Rack::Request.new(env)
      expect(w.as_json).to eq({"body" => "x", "headers" => {"X" => "1"}, "method" => "GET", "path" => "/a"})
    end
  end
end
