# frozen_string_literal: true

require "webhookdb/concurrent"

RSpec.describe Webhookdb::Concurrent do
  shared_examples_for "a concurrent pool" do
    it "processes tasks" do
      a = []
      pool.post { a << 1 }
      pool.post { a << 2 }
      pool.post { a << 3 }
      pool.join
      expect(a).to contain_exactly(1, 2, 3)
    end

    it "re-raises an existing error when posting once an error has occurred" do
      pool.post { raise "oops" }
      expect do
        # If we keep posting, we can make sure the earlier error task is done,
        # so one of these will raise.
        Array.new(20) do
          pool.post { nil }
        end
      end.to raise_error(RuntimeError, "oops")
    end
  end

  describe Webhookdb::Concurrent::SerialPool do
    it_behaves_like "a concurrent pool" do
      let(:pool) { described_class.new }
    end
  end

  describe Webhookdb::Concurrent::ParallelizedPool do
    it_behaves_like "a concurrent pool" do
      let(:pool) { described_class.new((2..10).to_a.sample, threads: 1) }
    end

    it "raises if posting after joining" do
      pool = described_class.new(3)
      pool.join
      expect { pool.post {} }.to raise_error(ClosedQueueError)
    end
  end
end
