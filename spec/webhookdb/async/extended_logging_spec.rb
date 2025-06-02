# frozen_string_literal: true

require "webhookdb/async/extended_logging"

RSpec.describe Webhookdb::Async::ExtendedLogging do
  before(:each) do
    @before_server_mw = Amigo::SpecHelpers::ServerCallbackMiddleware.reset

    Sidekiq.redis(&:flushdb)
    Sidekiq::Testing.disable!
    Sidekiq.server_middleware.add(@before_server_mw)
    Sidekiq.server_middleware.add(described_class::ServerMiddleware)
  end

  after(:each) do
    Sidekiq.server_middleware.entries.delete(@before_server_mw)
    Sidekiq.server_middleware.remove(described_class::ServerMiddleware)
    Sidekiq.redis(&:flushdb)
  end

  def create_job_class(callback=nil)
    cls = Class.new do
      include Sidekiq::Worker

      define_method(:perform) do |*args|
        callback && callback[self, args]
      end

      def self.to_s
        return "ExtendedLogging::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "logs additional fields" do
    called = false
    cb = proc { called = true }
    scope = Sentry::Scope.new
    expect(Sentry).to receive(:get_current_scope).and_return(scope)
    cls = create_job_class(cb)
    sidekiq_perform_inline(cls, [])
    expect(called).to be_truthy
    expect(scope.contexts).to include(sidekiq: include(started_at: be_positive))
  end
end
