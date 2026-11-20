# frozen_string_literal: true

require "webhookdb/async/timeout_retry"

RSpec.describe Webhookdb::Async::TimeoutRetry do
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
        return "TimeoutRetry::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "retries if a database connect timeout is raised" do
    calls = 0
    cb = proc do
      calls += 1
      begin
        raise PG::ConnectionBad,
              'connection to server at "abc.us-west-2.rds.amazonaws.com" (1.1.1.1), port 5432 failed: timeout expired'
      rescue PG::Error => e
        raise Sequel::DatabaseConnectionError, e
      end
    end
    cls = create_job_class(cb)
    expect { sidekiq_perform_inline(cls, []) }.to raise_error(Sequel::DatabaseConnectionError)
    expect(calls).to eq(3)
  end
end
