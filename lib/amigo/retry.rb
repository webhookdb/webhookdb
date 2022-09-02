# frozen_string_literal: true

require "sidekiq"

module Amigo
  # Placeholder until we're in Amigo proper
end

# Middleware so Sidekiq workers can use a custom retry logic.
# See +Amigo::Retry::Retry+, +Amigo::Retry::Die+,
# and +Amigo::Retry::OrDie+ for more details
# on how these should be used.
#
# NOTE: You MUST register +Amigo::Retry::ServerMiddleware+,
# and you SHOULD increase the size of the dead set if you are relying on 'die' behavior:
#
#   Sidekiq.configure_server do |config|
#     config.options[:dead_max_jobs] = 999_999_999
#     config.server_middleware.add(Amigo::Retry::ServerMiddleware)
#   end
module Amigo::Retry
  class Error < StandardError; end

  # Raise this class, or a subclass of it, to schedule a later retry,
  # rather than using an error to trigger Sidekiq's default retry behavior.
  # The benefit here is that it allows a consistent, customizable behavior,
  # so is better for 'expected' errors like rate limiting.
  class Retry < Error
    attr_accessor :interval_or_timestamp

    def initialize(interval_or_timestamp, msg=nil)
      @interval_or_timestamp = interval_or_timestamp
      super(msg || "retry job in #{interval_or_timestamp}")
    end
  end

  # Raise this class, or a subclass of it, to send the job to the DeadSet,
  # rather than going through Sidekiq's retry mechanisms.
  # This allows jobs to hard-fail when there is something like a total outage,
  # rather than retrying.
  class Die < Error
  end

  # Raise this class, or a subclass of it, to:
  # - Use +Retry+ exception semantics while the current attempt is <= +attempts+, or
  # - Use +Die+ exception semantics if the current attempt is > +attempts+.
  class OrDie < Error
    attr_reader :attempts, :interval_or_timestamp

    def initialize(attempts, interval_or_timestamp, msg=nil)
      @attempts = attempts
      @interval_or_timestamp = interval_or_timestamp
      super(msg || "retry every #{interval_or_timestamp} up to #{attempts} times")
    end
  end

  class ServerMiddleware
    def call(worker, job, _queue)
      yield
    rescue Amigo::Retry::Retry => e
      handle_retry(worker, job, e)
    rescue Amigo::Retry::Die => e
      handle_die(worker, job, e)
    rescue Amigo::Retry::OrDie => e
      handle_retry_or_die(worker, job, e)
    end

    def handle_retry(worker, job, e)
      Sidekiq.logger.info("scheduling_retry")
      self.amigo_retry_in(worker.class, job, e.interval_or_timestamp)
    end

    def handle_die(_worker, job, _e)
      Sidekiq.logger.warn("sending_to_deadset")
      payload = Sidekiq.dump_json(job)
      Sidekiq::DeadSet.new.kill(payload, notify_failure: false)
    end

    def handle_retry_or_die(worker, job, e)
      retry_count = job.fetch("retry_count", 0)
      if retry_count <= e.attempts
        handle_retry(worker, job, e)
      else
        handle_die(worker, job, e)
      end
    end

    def amigo_retry_in(worker_class, item, interval)
      # pulled from perform_in
      int = interval.to_f
      now = Time.now.to_f
      ts = (int < 1_000_000_000 ? now + int : int)
      item["at"] = ts if ts > now
      item["retry_count"] = item.fetch("retry_count", 0) + 1
      worker_class.client_push(item)
    end
  end
end
