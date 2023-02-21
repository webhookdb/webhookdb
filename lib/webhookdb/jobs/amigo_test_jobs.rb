# frozen_string_literal: true

require "amigo/retry"
require "amigo/queue_backoff_job"
require "amigo/durable_job"
require "sidekiq"

# Use this to verify the behavior of durable jobs:
#
# - Ensure DISABLE_DURABLE_JOBS_POLL env var is set.
# - `make run` and then `Webhookdb::Async.open_web` to go to Sidekiq web UI.
# - `make run-workers`, and copy the PID.
# - From pry: `Webhookdb::Jobs::DurableSleeper.setup_test_run(30)`
# - Jobs are put into the queue and the workers will be 'running' (sleeping).
# - Wait for some jobs to be done sleeping.
# - `pkill -9 <pid>`, kills Sidekiq without cleanup.
# - `Webhookdb::Jobs::DurableSleeper.print_status` will print
#   the queue size. It would be '10' if you started with 30 jobs,
#   10 processed, and the worker was killed while 10 more were processing
#   (leaving 10 unprocessed jobs in the queue).
#   It will also print dead jobs, which will be 0.
#   It will also print processed jobs, will be be 10.
# - Restart workers with `make run-workers`.
# - The next 10 workers will run (queue). `print_status` returns 0 for queue and dead size,
#   and 20 for jobs processed.
# - Run `Amigo::DurableJob.poll_jobs`.
# - Go to the web UI's Dead jobs. Observe 10 jobs are there. `print_status` also shows 10 jobs as dead.
# - Retry those jobs.
# - `print_status` shows 0 dead and 30 processed jobs.
#
class Webhookdb::Jobs::DurableSleeper
  include Sidekiq::Job
  include Amigo::DurableJob

  MUX = Mutex.new
  COUNTER_FILE = ".durable-sleeper-counter"

  def self.heartbeat_extension
    return 20.seconds
  end

  def perform(duration=5)
    self.logger.info("sleeping")
    sleep(duration)
    MUX.synchronize do
      done = File.read(COUNTER_FILE).to_i
      done += 1
      File.write(COUNTER_FILE, done.to_s)
    end
  end

  def self.setup_test_run(count=30)
    File.write(COUNTER_FILE, "0")
    count.times { Webhookdb::Jobs::DurableSleeper.perform_async }
  end

  def self.print_status
    done = File.read(COUNTER_FILE).to_i
    puts "Queue Size: #{Sidekiq::Queue.new.size}"
    puts "Processed:  #{done}"
    puts "Dead Set:   #{Sidekiq::DeadSet.new.size}"
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
