# frozen_string_literal: true

require "amigo/scheduled_job"

require "webhookdb/async"
require "webhookdb/async/job_common"

module Webhookdb::Async::ScheduledJob
  def self.extended(cls)
    cls.extend Amigo::ScheduledJob
    cls.extend Webhookdb::Async::JobCommon
  end
end
