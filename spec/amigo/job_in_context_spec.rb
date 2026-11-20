# frozen_string_literal: true

require "amigo/job_in_context"

RSpec.describe Amigo::JobInContext do
  before(:each) do
    @before_server_mw = Amigo::SpecHelpers::ServerCallbackMiddleware.reset

    Sidekiq.redis(&:flushdb)
    Sidekiq::Testing.disable!
    Sidekiq.default_configuration.server_middleware.add(@before_server_mw)
    Sidekiq.default_configuration.server_middleware.add(described_class::ServerMiddleware)
  end

  after(:each) do
    Sidekiq.default_configuration.server_middleware.entries.delete(@before_server_mw)
    Sidekiq.default_configuration.server_middleware.remove(described_class::ServerMiddleware)
    Sidekiq.redis(&:flushdb)
  end

  def create_job_class(callback=nil)
    cls = Class.new do
      include Sidekiq::Worker

      define_method(:perform) do |*args|
        callback && callback[self, args]
      end

      def self.to_s
        return "JobInContext::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "puts the worker, job, and queue in context" do
    cb = proc {
      expect(Sidekiq::Context.current).to include(
        job_hash: include("args" => [1, 2, 3], "class" => "JobInContext::TestWorker"),
        queue: "default",
        worker: have_attributes(class: have_attributes(name: "JobInContext::TestWorker")),
      )
    }
    cls = create_job_class(cb)
    sidekiq_perform_inline(cls, [1, 2, 3])
    expect(Sidekiq::Context.current).to be_empty
  end
end
