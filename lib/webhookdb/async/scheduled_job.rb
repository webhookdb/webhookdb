# frozen_string_literal: true

require "amigo/scheduled_job"

require "webhookdb/async"

module Webhookdb::Async::ScheduledJob
  def self.extended(cls)
    cls.extend Amigo::ScheduledJob
    cls.include(InstanceMethods)
  end

  module InstanceMethods
    def with_log_tags(tags, &)
      Webhookdb::Async::JobLogger.with_log_tags(tags, &)
    end

    def set_job_tags(**tags)
      Webhookdb::Async::JobLogger.set_job_tags(**tags)
    end
  end
end
