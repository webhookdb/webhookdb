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

    it "does not enqueue tasks once an error has occurred" do
      a = []
      pool.post { a << 1 }
      pool.post { raise "oops" }
      pool.post { a << 2 }
      pool.post { a << 3 }
      pool.post { a << 4 }
      expect do
        pool.join
      end.to raise_error(RuntimeError, "oops")
      expect(a).to contain_exactly(1)
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
