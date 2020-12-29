# frozen_string_literal: true

require "webhookdb/fixtures"

RSpec.describe Webhookdb::Fixtures do
  it "sets the path prefix for fixtures" do
    expect(described_class.fixture_path_prefix).to eq("webhookdb/fixtures")
  end
end
