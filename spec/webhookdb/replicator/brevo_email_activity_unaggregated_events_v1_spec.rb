# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1, :db do
  describe "helper tests" do
    it "correctly replaces a key in a hash" do
      body = {"message-id" => "first-id"}
      body[:messageId] = body.delete "message-id"
      $stderr.puts ">>>>> body[:messageId] = #{body[:messageId]}"
      expect(body[:messageId]).to eq "first-id"
    end
  end
end
