# frozen_string_literal: true

require "sidekiq"
require "sidekiq-cron"

require "webhookdb/async"

module Webhookdb::Async::ScheduledJob
  def self.extended(cls)
    Webhookdb::Async.jobs << cls

    cls.include(Sidekiq::Worker)
    cls.extend(ClassMethods)
    cls.class_attribute :cron_expr
    cls.class_attribute :splay_duration
    cls.splay_duration = 30.seconds
    cls.include(InstanceMethods)
  end

  module InstanceMethods
    def logger
      return Webhookdb::Async::JobLogger.logger
    end

    def perform(*args)
      if args.empty?
        jitter = rand(0..self.splay_duration.to_i)
        self.class.perform_in(jitter, true)
      elsif args == [true]
        self._perform
      else
        raise "ScheduledJob#perform must be called with no arguments, or [true]"
      end
    end
  end

  module ClassMethods
    def scheduled_job?
      return true
    end

    def event_job?
      return false
    end

    # Return the UTC hour for the given hour and timezone.
    # For example, during DST, `utc_hour(6, 'US/Pacific')` returns 13 (or, 6 + 7),
    # while in standard time (not DST) it returns 8 (or, 6 + 8).
    # This is useful in crontab notation, when we want something to happen at
    # a certain local time and don't want it to shift with DST.
    def utc_hour(hour, timezone)
      return Time.now.in_time_zone(timezone).change(hour: hour).in_time_zone("UTC").hour
    end

    def cron(expr)
      self.cron_expr = expr
    end

    def splay(duration)
      self.splay_duration = duration
    end
  end
end
