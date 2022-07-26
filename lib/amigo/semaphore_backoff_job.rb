# frozen_string_literal: true

require "sidekiq"

module Amigo
  # This is a placeholder until it's migrated to Amigo proper
end

# Semaphore backoff jobs can reschedule themselves to happen at a later time
# if there is too high a contention on a semaphore.
# Ie, if there are too many jobs with the same key,
# they start to reschedule themselves for the future.
#
# This is useful when a certain job (or job for a certain target)
# can be slow so should not consume all available resources.
#
# In general, you should not use semaphore backoff jobs for singletons,
# as the guarantees are not strong enough.
# It is useful for many rapid jobs.
#
# Implementers must override the following methods:
#
# - `semaphore_key` must return the Redis key to use as the semaphore.
#   This may be something like "sbj-user-1" to limit jobs for user 1.
# - `semaphore_size` is the number of concurrent jobs.
#   Returning 5 would mean at most 5 jobs could be running at a time.
#
# And may override the following methods:
#
# - `semaphore_backoff` is called to know when to schedule the backoff retry.
#   By default, it is 10 seconds, plus between 0 and 10 seconds more,
#   so the job will be retried in between 10 and 20 seconds.
#   Return whatever you want for the backoff.
# - `semaphore_expiry` should return the TTL of the semaphore key.
#   Defaults to 30 seconds. See below for key expiry and negative semaphore value details.
# - `before_perform` is called before calling the `perform` method.
#   This is required so that implementers can set worker state, based on job arguments,
#   that can be used for calculating the semaphore key.
#
# Note that we give the semaphore key an expiry. This is to avoid situation where
# jobs are killed, the decrement is not done, and the counter increases to the point we
# have fewer than the expected number of jobs running.
#
# This does mean that, when a job runs longer than the semaphore expiry,
# another worker can be started, which would increment the counter back to 1.
# When the original job ends, the counter would be 0; then when the new job ends,
# the counter would be -1. To avoid negative counters (which create the same issue
# around missing decrements), if we ever detect a negative 'jobs running',
# we warn and remove the key entirely.
#
module Amigo::SemaphoreBackoffJob
  def self.included(cls)
    cls.include InstanceMethods
    cls.prepend PrependedMethods
  end

  class << self
    # Reset class state. Mostly used just for testing.
    def reset
      is_testing = defined?(::Sidekiq::Testing) && ::Sidekiq::Testing.enabled?
      @enabled = !is_testing
    end

    # Return true if backoff checks are enabled.
    attr_accessor :enabled

    def enabled? = @enabled
  end

  self.reset

  module InstanceMethods
    def semaphore_key
      raise NotImplementedError, "must be implemented on worker"
    end

    def semaphore_size
      raise NotImplementedError, "must be implemented on worker"
    end

    def semaphore_backoff
      return 10 + (rand * 10)
    end

    def semaphore_expiry
      return 30
    end
  end

  module PrependedMethods
    def perform(*args)
      self.before_perform(*args) if self.respond_to?(:before_perform)
      return super unless ::Amigo::SemaphoreBackoffJob.enabled?
      key = self.semaphore_key
      size = self.semaphore_size
      # Create a simple counter for the semaphore key.
      # Always increment; also set an expiration if this is the first job.
      # If we need to retry later, make sure we decrement, then schedule for the future.
      # If we run it now, decrement the counter afterwards.
      # If some corruption results in a negative number of jobs in the semaphore,
      # we can delete the key and get back to a default state
      # (this can cause problems but the idea is that
      # we should run at least the configured number of jobs,
      # and eventually the semaphore key will expire/get rebalanced).
      jobs_in_semaphore = Sidekiq.redis do |conn|
        cnt = conn.incr(key)
        conn.expire(key, self.semaphore_expiry) if cnt == 1
        cnt
      end
      if jobs_in_semaphore > size
        Sidekiq.redis { |conn| conn.decr(key) }
        backoff = self.semaphore_backoff
        self.class.perform_in(backoff, *args)
        return
      end
      begin
        super
      ensure
        Sidekiq.redis do |conn|
          new_job_count = conn.decr(key)
          if new_job_count.negative?
            conn.del(key)
            Sidekiq.logger.warn("negative_semaphore_backoff_job_count", job_count: new_job_count)
          end
        end
      end
    end
  end
end
