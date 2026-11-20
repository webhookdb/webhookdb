# frozen_string_literal: true

require "webhookdb/developer_alert"

RSpec.describe Webhookdb::DeveloperAlert do
  describe "as_json" do
    it "ensures the payload passes Sidekiq validation" do
      jobscls = Class.new do
        include Sidekiq::JobUtil
        def jsonunsafe?(*) = json_unsafe?(*)
      end
      scls = Class.new(String)
      s = scls.new("y")
      alert = described_class.new(subsystem: s, emoji: "", fallback: "", fields: {x: s})
      expect(jobscls.new.jsonunsafe?(alert.as_json)).to be_nil
    end
  end
end
