# frozen_string_literal: true

require "amigo/backoff_job"

RSpec.describe Amigo::BackoffJob do
  before(:each) do
    Sidekiq::Testing.fake!
    described_class.reset
    described_class.enabled = true
  end

  after(:each) do
    Sidekiq::Worker.drain_all
    described_class.reset
  end

  nocall = ->(*) { raise "should not be called" }

  def create_job_class(perform:, dependent_queues:, calculate_backoff:)
    cls = Class.new do
      include Sidekiq::Worker
      include Amigo::BackoffJob

      perform && define_method(:perform) do |*args|
        perform[*args]
      end

      dependent_queues && define_method(:dependent_queues) do
        dependent_queues.call
      end

      calculate_backoff && define_method(:calculate_backoff) do |queue, latency, args|
        calculate_backoff[queue, latency, args]
      end

      def self.to_s
        return "BackoffJob::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  def mock_queue(name, latency)
    q = instance_double(Sidekiq::Queue)
    expect(q).to receive(:latency).and_return(latency)
    expect(Sidekiq::Queue).to receive(:new).with(name).and_return(q)
    return q
  end

  it "can be enabled and disabled" do
    described_class.enabled = false
    calls = []
    kls = create_job_class(
      perform: ->(a) { calls << a },
      dependent_queues: nocall,
      calculate_backoff: nocall,
    )
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end

  it "calls perform if none of the dependent queues have latency" do
    mock_queue("q1", 0)
    calls = []
    kls = create_job_class(
      perform: ->(a) { calls << a },
      dependent_queues: -> { ["q1"] },
      calculate_backoff: nocall,
    )
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end

  it "passes the first queue with latency to calculate_backoff" do
    mock_queue("q1", 0)
    mock_queue("q2", 1)

    calc_calls = []
    kls = create_job_class(
      perform: ->(*) {},
      dependent_queues: -> { ["q1", "q2"] },
      calculate_backoff: lambda { |q, lat, args|
        calc_calls << [q, lat, args]
        nil
      },
    )
    kls.perform_async(1)
    kls.drain
    expect(calc_calls).to eq([["q2", 1, [1]]])
  end

  it "reschedules via perform_in using the result of calculate_backoff" do
    mock_queue("q1", 1)
    kls = create_job_class(
      perform: nocall,
      dependent_queues: -> { ["q1", "q2"] },
      calculate_backoff: ->(*) { 20 },
    )
    expect(kls).to receive(:perform_in).with(20, 1)
    kls.perform_async(1)
    kls.drain
  end

  it "checks the remaining queues if calculate_backoff returns nil, falling back to immediate call" do
    mock_queue("q1", 1)
    mock_queue("q2", 2)
    mock_queue("q3", 3)
    perform_calls = []
    backoff_calls = []
    kls = create_job_class(
      perform: ->(a) { perform_calls << a },
      dependent_queues: -> { ["q1", "q2", "q3"] },
      calculate_backoff: lambda { |*args|
        backoff_calls << args
        nil
      },
    )
    kls.perform_async(1)
    kls.drain
    expect(perform_calls).to eq([1])
    expect(backoff_calls).to eq([["q1", 1, [1]], ["q2", 2, [1]], ["q3", 3, [1]]])
  end

  it "does not check remaining queues, and calls perform if calculate_backoff returns <= 0" do
    mock_queue("q1", 0)
    mock_queue("q2", 2)
    perform_calls = []
    backoff_calls = []
    kls = create_job_class(
      perform: ->(a) { perform_calls << a },
      dependent_queues: -> { ["q1", "q2", "q3"] },
      calculate_backoff: lambda { |*args|
        backoff_calls << args
        0
      },
    )
    kls.perform_async(1)
    kls.drain
    expect(perform_calls).to eq([1])
    expect(backoff_calls).to eq([["q2", 2, [1]]])
  end

  it "uses the latency as the backoff if less than 10s" do
    mock_queue("q1", 8)
    kls = create_job_class(
      perform: nocall,
      dependent_queues: -> { ["q1"] },
      calculate_backoff: nil,
    )
    kls.perform_async(1)
    expect(kls).to receive(:perform_in).with(8, 1)
    kls.drain
  end

  it "uses 10s as the default max latency" do
    mock_queue("q1", 50)
    kls = create_job_class(
      perform: nocall,
      dependent_queues: -> { ["q1"] },
      calculate_backoff: nil,
    )
    kls.perform_async(1)
    expect(kls).to receive(:perform_in).with(10, 1)
    kls.drain
  end

  it "uses all queues, other than the current queue, as the default" do
    expect(Sidekiq::Queue).to receive(:all).
      and_return([Sidekiq::Queue.new("q1"), Sidekiq::Queue.new("q2"), Sidekiq::Queue.new("q3")])
    kls = create_job_class(
      perform: nocall,
      dependent_queues: nil,
      calculate_backoff: nocall,
    )
    kls.sidekiq_options queue: "q2"
    expect(kls.new.dependent_queues).to eq(["q1", "q3"])
  end

  describe "queue caching" do
    it "caches the result of all queues" do
      expect(Sidekiq::Queue).to receive(:all).once.and_return([Sidekiq::Queue.new("q1")])
      kls = create_job_class(
        perform: nocall,
        dependent_queues: nil,
        calculate_backoff: nocall,
      )
      expect(kls.new.dependent_queues).to eq(["q1"])
      expect(kls.new.dependent_queues).to eq(["q1"])
    end

    it "can be disabled" do
      expect(Sidekiq::Queue).to receive(:all).and_return([Sidekiq::Queue.new("q1")])
      expect(Sidekiq::Queue).to receive(:all).and_return([Sidekiq::Queue.new("q2")])
      expect(Sidekiq::Queue).to receive(:all).and_return([Sidekiq::Queue.new("q3")])
      kls = create_job_class(
        perform: nocall,
        dependent_queues: nil,
        calculate_backoff: nocall,
      )
      expect(kls.new.dependent_queues).to eq(["q1"])
      described_class.cache_queue_names = false
      expect(kls.new.dependent_queues).to eq(["q2"])
      expect(kls.new.dependent_queues).to eq(["q3"])
    end
  end

  describe "latency caching" do
    it "is enabled by default" do
      q1 = Sidekiq::Queue.new("q1")
      expect(q1).to receive(:latency).and_return(3)
      expect(q1).to receive(:latency).and_return(5)
      expect(Sidekiq::Queue).to receive(:new).with("q1").twice.and_return(q1)

      now = Time.now
      expect(described_class.check_latency("q1", now:)).to eq(3)
      expect(described_class.check_latency("q1", now:)).to eq(3)
      expect(described_class.check_latency("q1", now: now + 6.seconds)).to eq(5)
    end

    it "can be disabled" do
      described_class.latency_cache_duration = 0

      q1 = Sidekiq::Queue.new("q1")
      expect(q1).to receive(:latency).and_return(3)
      expect(q1).to receive(:latency).and_return(5)
      expect(Sidekiq::Queue).to receive(:new).with("q1").twice.and_return(q1)

      expect(described_class.check_latency("q1")).to eq(3)
      expect(described_class.check_latency("q1")).to eq(5)
    end
  end
end
