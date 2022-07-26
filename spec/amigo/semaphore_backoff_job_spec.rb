# frozen_string_literal: true

require "amigo/semaphore_backoff_job"

RSpec.describe Amigo::SemaphoreBackoffJob do
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

  def create_job_class(perform:, key: "semkey", size: 5, &block)
    cls = Class.new do
      include Sidekiq::Worker
      include Amigo::SemaphoreBackoffJob

      define_method(:perform) { |*args| perform[*args] }
      define_method(:semaphore_key) { key }
      define_method(:semaphore_size) { size }

      def self.to_s
        return "SemaphoreBackoffJob::TestWorker"
      end

      block && class_eval do
        yield(self)
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "can be enabled and disabled" do
    described_class.enabled = false
    calls = []
    kls = create_job_class(perform: ->(a) { calls << a }, key: nocall, size: nocall)
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end

  it "calls perform if the semaphore is below max size" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("semkey").and_return(1)
      expect(c).to receive(:expire).with("semkey", 30)
      expect(c).to receive(:decr).with("semkey").and_return(0)
    end
    calls = []
    kls = create_job_class(perform: ->(a) { calls << a })
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end

  it "only sets key expiry for the first job taking the semaphore" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("semkey").and_return(2)
      expect(c).to receive(:decr).with("semkey").and_return(1)
    end
    calls = []
    kls = create_job_class(perform: ->(a) { calls << a })
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end

  it "invokes before_perform if provided" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("k-myarg").and_return(2)
      expect(c).to receive(:decr).with("k-myarg").and_return(1)
    end
    calls = []
    kls = create_job_class(perform: ->(a) { calls << a }) do |this|
      this.define_method(:before_perform) do |args|
        @args = args
      end
      this.define_method(:semaphore_key) do
        "k-#{@args}"
      end
    end
    kls.perform_async("myarg")
    kls.drain
    expect(calls).to eq(["myarg"])
  end

  it "reschedules via perform_in using the result of sempahore_backoff" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("semkey").and_return(6)
      expect(c).to receive(:decr).with("semkey").and_return(5)
    end
    kls = create_job_class(perform: nocall) do |this|
      this.define_method(:semaphore_backoff) do
        6
      end
    end
    expect(kls).to receive(:perform_in).with(6, 1)
    kls.perform_async(1)
    kls.drain
  end

  it "reschedules with a default semaphore backoff" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("semkey").and_return(6)
      expect(c).to receive(:decr).with("semkey").and_return(5)
    end
    kls = create_job_class(perform: nocall)
    expect(kls).to receive(:perform_in).with((be >= 10).and(be <= 20), 1)
    kls.perform_async(1)
    kls.drain
  end

  it "expires the key if the decrement returns a negative value" do
    Sidekiq.redis do |c|
      expect(c).to receive(:incr).with("semkey").and_return(2)
      expect(c).to receive(:decr).with("semkey").and_return(-1)
      expect(c).to receive(:del).with("semkey")
    end
    calls = []
    kls = create_job_class(perform: ->(a) { calls << a })
    kls.perform_async(1)
    kls.drain
    expect(calls).to eq([1])
  end
end
