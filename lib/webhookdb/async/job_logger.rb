# frozen_string_literal: true

require "appydays/loggable/sidekiq_job_logger"

class Webhookdb::Async::JobLogger < Appydays::Loggable::SidekiqJobLogger
  protected def slow_job_seconds
    return Webhookdb::Async.slow_job_seconds
  end
end
