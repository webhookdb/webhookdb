# frozen_string_literal: true

require "amigo/job"

require "webhookdb/async"

module Webhookdb::Async::Job
  def self.extended(cls)
    cls.extend Amigo::Job
    cls.include(InstanceMethods)
  end

  module InstanceMethods
    def with_log_tags(tags, &)
      Webhookdb::Async::JobLogger.with_log_tags(tags, &)
    end
  end
end
