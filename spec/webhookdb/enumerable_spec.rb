# frozen_string_literal: true

require "webhookdb/enumerable"

RSpec.describe Webhookdb::Enumerable do
  describe "group_and_count_by" do
    it "groups and counts by the given block" do
      arr = [1, 3, 5, 2]
      result = described_class.group_and_count_by(arr, &:even?)
      expect(result).to eq(true => 1, false => 3)
    end
  end

  describe "group_and_count" do
    it "groups and counts with an identity block" do
      arr = [:a, :b, :a, :c]
      result = described_class.group_and_count(arr)
      expect(result).to eq(a: 2, b: 1, c: 1)
    end
  end
end
