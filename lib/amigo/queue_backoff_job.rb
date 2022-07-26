# frozen_string_literal: true

require "sidekiq"
require "sidekiq/api"

module Amigo
  # This is a placeholder until it's migrated to Amigo proper
end

# Queue backoff jobs can reschedule themselves to happen at a later time
# if one of their dependent queues has latency.
# This is commonly needed where a lower-priority queue has longer-running jobs
# (such as paginating through an external API)
# that should be kept from blocking higher-priority queues
# (such as sending emails to users).
#
# Implementers must override two methods:
#
# - `dependent_queues` should return an array of the names of queues that should be checked,
#   in order of higher-priority-first. See below for notes.
# - `calculate_backoff` is passed a queue name and its latency,
#   and should return 1) the backoff duration in seconds (ie the argument to `perform_in`),
#   0 to perform the job immediately, or nil to check the next queue with latency.
#   Note that if all calls to `calculate_backoff` return nil, the job is performed immediately.
#
# BackoffJob supports multiple dependent queues but it checks them one-at-a-time
# to avoid any unnecessary calls to Redis.
#
# == Redis Impacts
#
# Using BackoffJob adds an overhead to each perform of a job-
# specifically, a call to `Redis.lrange` through the Sidekiq API's Sidekiq:::Queue#latency
# potentially for each queue in `dependent_queues`.
# This is a fast call (it just gets the last item), but it's not free,
# so users should be aware of it.
#
module Amigo::QueueBackoffJob
  def self.included(cls)
    cls.include InstanceMethods
    cls.prepend PrependedMethods
  end

  class << self
    # Reset class state. Mostly used just for testing.
    def reset
      @max_backoff = 10
      is_testing = defined?(::Sidekiq::Testing) && ::Sidekiq::Testing.enabled?
      @enabled = !is_testing
      @cache_queue_names = true
      @cache_latencies = true
      @all_queue_names = nil
      @latency_cache_duration = 5
      @latency_cache = {}
    end

    # Maximum time into the future a job will reschedule itself for.
    # Ie, if latency is 30s, and max_backoff is 10, the job will be scheduled
    # for 10s into the future if it finds backoff pressure.
    attr_accessor :max_backoff

    # Return true if backoff checks are enabled.
    attr_accessor :enabled

    def enabled? = @enabled

    # Cached value of all Sidekiq queues, since they rarely change.
    # If your queue names change at runtime, set +cache_queue_names+ to false.
    def all_queue_names
      return @all_queue_names if @cache_queue_names && @all_queue_names
      @all_queue_names = ::Sidekiq::Queue.all.map(&:name)
      return @all_queue_names
    end

    # Whether all_queue_names should be cached.
    attr_reader :cache_queue_names

    def cache_queue_names=(v)
      @cache_queue_names = v
      @all_queue_names = nil if v == false
    end

    # Return how long queue latencies should be cached before they are re-fetched from Redis.
    # Avoids hitting Redis to check latency too often.
    # Default to 5 seconds. Set to 0 to avoid caching.
    attr_accessor :latency_cache_duration

    # Check the latency of the queue with the given now.
    # If the queue has been checked more recently than latency_cache_duration specified,
    # return the cached value.
    def check_latency(qname, now: Time.now)
      return ::Sidekiq::Queue.new(qname).latency if self.latency_cache_duration.zero?
      cached = @latency_cache[qname]
      if cached.nil? || (cached[:at] + self.latency_cache_duration) < now
        @latency_cache[qname] = {at: now, value: ::Sidekiq::Queue.new(qname).latency}
      end
      return @latency_cache[qname][:value]
    end
  end
  self.reset

  module InstanceMethods
    def dependent_queues
      qname = self.class.get_sidekiq_options["queue"]
      return ::Amigo::QueueBackoffJob.all_queue_names.excluding(qname)
    end

    def calculate_backoff(_queue_name, latency, _args)
      return [latency, ::Amigo::QueueBackoffJob.max_backoff].min
    end
  end

  module PrependedMethods
    def perform(*args)
      return super unless ::Amigo::QueueBackoffJob.enabled?
      # rubocop:disable Style/GuardClause, Lint/NonLocalExitFromIterator
      dependent_queues.each do |qname|
        latency = Amigo::QueueBackoffJob.check_latency(qname)
        # If latency is <= 0, we can skip this queue.
        next unless latency.positive?
        # If backoff is nil, ignore this queue and check the next
        # If it's > 0, defer until the future
        # If it's <= 0, run the job and check no more queues
        backoff = calculate_backoff(qname, latency, args)
        next if backoff.nil?
        if backoff.positive?
          self.class.perform_in(backoff, *args)
          return
        else
          return super
        end
      end
      # rubocop:enable Style/GuardClause, Lint/NonLocalExitFromIterator
      super
    end
  end
end
