# frozen_string_literal: true

require "webhookdb/async"

module Webhookdb::Async::JobCommon
  def self.extended(cls)
    cls.include(InstanceMethods)
  end

  module InstanceMethods
    def with_log_tags(*tag, **tags, &)
      tags.merge!(tag.first) if tag.any?
      Webhookdb::Async::JobLogger.with_log_tags(tags, &)
    end

    def set_job_tags(*tag, **tags)
      tags.merge!(tag.first) if tag.any?
      Webhookdb::Async::JobLogger.set_job_tags(**tags)
    end

    def long_running_job_heartbeat!
      raise Sidekiq::Shutdown if Webhookdb::Async.stop_processing_jobs?
    end
  end
end
