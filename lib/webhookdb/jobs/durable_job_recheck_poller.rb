# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::DurableJobRecheckPoller
  extend Webhookdb::Async::ScheduledJob

  cron "*/3 * * * *"
  splay 20

  def _perform
    return if ENV["DISABLE_DURABLE_JOBS_POLL"]
    Amigo::DurableJob.poll_jobs
  end
end
