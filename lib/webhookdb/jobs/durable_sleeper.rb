# frozen_string_literal: true

require "amigo/durable_job"
require "sidekiq"

# Use this to verify the behavior of durable jobs:
#
# - Ensure DISABLE_DURABLE_JOBS_POLL env var is set.
# - `make run-workers`, and copy the PID
# - From pry: `Webhookdb::Async.require_jobs; 100.times { Webhookdb::Jobs::DurableSleeper.perform_async }`
# - `pkill -9 <pid>`, kills Sidekiq without cleanup
# - `make psql` and `SELECT * FROM durable_jobs`, see that a bunch of stuff is there (but not all 100 rows)
# - `Sidekiq::Queue.new.size`, should be less than the number of rows remaining in durable_jobs table.
# - `make run-workers` again, watch the jobs drain. Eventually `Sidekiq::Queue.new.size`,
#   and `SELECT * from durable_jobs` will return some nonzero amount.
# - Run `Amigo::DurableJob.poll_jobs`, should add new jobs to the queue, and they should drain.
#
class Webhookdb::Jobs::DurableSleeper
  include Sidekiq::Job
  include Amigo::DurableJob

  def heartbeat_extension
    return 20.seconds
  end

  def perform(duration=5)
    sleep(duration)
  end
end
