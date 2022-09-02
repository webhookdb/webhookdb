# frozen_string_literal: true

require "amigo/retry"

class Sidekiq::Worker::Setter
  class << self
    attr_accessor :override_item
  end
  def normalize_item(item)
    result = super
    result.merge!(self.class.override_item || {})
    return result
  end
end

RSpec.describe Amigo::Retry do
  before(:each) do
    Sidekiq.redis(&:flushdb)
    Sidekiq::Testing.disable!
    Sidekiq.server_middleware.add(described_class::ServerMiddleware)
  end

  after(:each) do
    Sidekiq.server_middleware.remove(described_class::ServerMiddleware)
    Sidekiq.redis(&:flushdb)
  end

  def create_job_class(perform: nil, ex: nil, &block)
    raise "pass :perform or :ex" unless perform || ex
    cls = Class.new do
      include Sidekiq::Worker

      define_method(:perform) do |*args|
        raise ex if ex
        perform[*args]
      end

      def self.to_s
        return "Retry::TestWorker"
      end

      block && class_eval do
        yield(self)
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  def runjobs(q)
    alljobs(q).each do |job|
      klass = job.item["class"].constantize
      Sidekiq::Worker::Setter.override_item = job.item
      begin
        klass.perform_inline(*job.item["args"])
      ensure
        Sidekiq::Worker::Setter.override_item = nil
      end
      job.delete
    end
  end

  def alljobs(q)
    arr = []
    q.each { |j| arr << j }
    return arr
  end

  it "catches retry exceptions and reschedules with the given interval" do
    kls = create_job_class(ex: Amigo::Retry::Retry.new(30))
    kls.perform_async(1)

    expect(alljobs(Sidekiq::Queue.new)).to have_length(1)
    runjobs(Sidekiq::Queue.new)

    expect(alljobs(Sidekiq::ScheduledSet.new)).to contain_exactly(
      have_attributes(
        score: match_time(30.seconds.from_now).within(5),
        item: include("retry_count" => 1),
      ),
    )

    # Continue to retry
    runjobs(Sidekiq::ScheduledSet.new)
    sched2 = alljobs(Sidekiq::ScheduledSet.new)
    expect(sched2).to have_length(1)
    expect(sched2.first).to have_attributes(
      score: match_time(30.seconds.from_now).within(5),
      item: include("retry_count" => 2),
    )
  end

  it "retries on the correct queue" do
    kls = create_job_class(ex: Amigo::Retry::Retry.new(30)) do |cls|
      cls.sidekiq_options queue: "otherq"
    end
    kls.perform_async(1)

    jobs = alljobs(Sidekiq::Queue.new("otherq"))
    expect(jobs).to have_length(1)
    runjobs(Sidekiq::Queue.new("otherq"))

    # Should have moved to retry set
    sched = alljobs(Sidekiq::ScheduledSet.new)
    expect(sched).to have_length(1)
    expect(sched.first).to have_attributes(queue: "otherq")
  end

  it "catches die exceptions and sends to the dead set" do
    kls = create_job_class(ex: Amigo::Retry::Die.new)
    kls.perform_async(1)

    runjobs(Sidekiq::Queue.new)

    # Ends up in dead set, not scheduled set
    expect(alljobs(Sidekiq::ScheduledSet.new)).to be_empty
    dead = alljobs(Sidekiq::DeadSet.new)
    expect(dead).to have_length(1)
    expect(dead.first).to have_attributes(klass: kls.name, args: [1])
  end

  it "can conditionally retry or die depending on the retry count" do
    kls = create_job_class(ex: Amigo::Retry::OrDie.new(2, 30))
    kls.perform_async(1)

    runjobs(Sidekiq::Queue.new) # will go to be retried
    expect(alljobs(Sidekiq::ScheduledSet.new)).to have_length(1)
    runjobs(Sidekiq::ScheduledSet.new) # retry once
    expect(alljobs(Sidekiq::ScheduledSet.new)).to have_length(1)
    runjobs(Sidekiq::ScheduledSet.new) # retry twice
    expect(alljobs(Sidekiq::ScheduledSet.new)).to have_length(1)
    runjobs(Sidekiq::ScheduledSet.new) # the third retry moves to the dead set
    expect(alljobs(Sidekiq::DeadSet.new)).to have_length(1)
  end
end
