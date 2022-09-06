# frozen_string_literal: true

require "amigo/retry"
require "amigo/queue_backoff_job"
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

# Use this and BackoffShouldBeRun to test the behavior of BackoffJob.
#
# First, fill up the 'netout' queue with a ton of these slow jobs:
# From pry: `Webhookdb::Async.require_jobs; 500.times { Webhookdb::Jobs::BackoffShouldBeRescheduled.perform_async }`
#
# Then, fill up the other queues with fast jobs:
# `1000.times { Webhookdb::Jobs::BackoffShouldRun.perform_async }`
#
# Then go to http://localhost:18001/sidekiq (user/pass) to check the latency.
# The netout queue should get slow,
# but the other queues should not build up much of a backlog.
class Webhookdb::Jobs::BackoffShouldBeRescheduled
  include Sidekiq::Job
  include Amigo::DurableJob # Uncomment to verify performance with durable jobs, which hit the DB.
  include Amigo::QueueBackoffJob

  sidekiq_options queue: "netout"

  def perform(duration=3)
    sleep(duration)
  end
end

class Webhookdb::Jobs::BackoffShouldRun
  include Sidekiq::Job

  def perform(duration=0.1)
    sleep(duration)
  end
end

class Webhookdb::Jobs::RetryChecker
  include Sidekiq::Job

  def perform(action, interval, attempts)
    case action
      when "retry"
        raise Amigo::Retry::Retry, interval
      when "die"
        raise Amigo::Retry::Die
    else
        raise Amigo::Retry::Die.new(attempts, interval)
    end
  end
end

class Webhookdb::Jobs::Erroring
  include Sidekiq::Job

  def perform(succeed: false)
    return if succeed
    raise "erroring as asked!"
  end
end
