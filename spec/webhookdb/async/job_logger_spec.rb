# frozen_string_literal: true

require "webhookdb/async/job_logger"

RSpec.describe Webhookdb::Async::JobLogger, :db do
  before(:all) do
    @slow_secs = Webhookdb::Async.slow_job_seconds
  end

  after(:each) do
    Webhookdb::Async.slow_job_seconds = @slow_secs
  end

  let(:logger) { described_class.new }

  def log(&block)
    block ||= proc {}
    lines = capture_logs_from(described_class.logger, formatter: :json) do
      logger.call({}, nil) do
        block.call
      end
    rescue StandardError => e
      nil
    end
    return lines
  end

  it "logs a info message for the job" do
    lines = log
    expect(lines).to contain_exactly(
      include_json(
        level: "info",
        name: "Webhookdb::Async::JobLogger",
        message: "job_done",
        duration_ms: be_a(Numeric),
      ),
    )
  end

  it "logs at warn if the time taken is more than the slow job seconds" do
    Webhookdb::Async.slow_job_seconds = 0
    lines = log
    expect(lines).to contain_exactly(
      include_json(
        level: "warn",
        name: "Webhookdb::Async::JobLogger",
        message: "job_done",
        duration_ms: be_a(Numeric),
      ),
    )
  end

  it "logs at error (but does not log the exception) if the job fails" do
    lines = log do
      1 / 0
    end

    expect(lines).to contain_exactly(
      include_json(
        level: "error",
        name: "Webhookdb::Async::JobLogger",
        message: "job_fail",
        duration_ms: be_a(Numeric),
      ),
    )
    expect(lines[0]).to_not include("exception")
  end
end
