# frozen_string_literal: true

require "webhookdb/async/resilient_sidekiq_client"

RSpec.describe Webhookdb::Async::ResilientSidekiqClient do
  include Webhookdb::SpecHelpers::Async::ResilientAction

  def create_job_class(calls)
    cls = Class.new do
      include Sidekiq::Worker
      sidekiq_options client_class: Webhookdb::Async::ResilientSidekiqClient

      define_method(:perform) { |arg| calls << arg }

      def self.to_s
        return "Resilient::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "can save a job" do
    expect(Sidekiq.redis_pool).to receive(:with) { raise RedisClient::ConnectionError, "from testing" }
    cls = create_job_class(nil)
    Sidekiq::Testing.disable! do
      cls.perform_async
    end
    expect(resilient_jobs_dataset(&:all)).to contain_exactly(
      include(
        json_meta: "{}",
        json_payload: include('"class":"Resilient::TestWorker"'),
      ),
    )
  end

  it "can replay jobs" do
    resilient = described_class.new(pool: Sidekiq.redis_pool).resilient
    calls = []
    create_job_class(calls)
    resilient.write_to(
      resilient_url,
      [
        {
          retry: true,
          queue: "default",
          client_class: "Webhookdb::Async::ResilientSidekiqClient",
          args: [-1],
          class: "Resilient::TestWorker",
          jid: "f7243752db68a1129cd33775",
          created_at: 1_749_407_361.819776,
        },
      ].to_json,
      "{}",
    )
    Sidekiq::Testing.inline! do
      described_class.resilient_replay
    end
    expect(resilient_jobs_dataset(&:all)).to be_empty
    expect(calls).to eq([-1])
  end
end
