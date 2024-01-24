# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1, :db do
  describe "correctly replaces a key in a hash" do
    body = { "message-id" => "first-id" }
    body[:messageId] = body.delete "message-id"
    expect(body[:messageId]).to eq "first-id"
  end
end