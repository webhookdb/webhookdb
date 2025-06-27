# frozen_string_literal: true

require "amigo/job"

require "webhookdb/async"
require "webhookdb/async/job_common"

module Webhookdb::Async::Job
  def self.extended(cls)
    cls.extend Amigo::Job
    cls.extend Webhookdb::Async::JobCommon
  end
end
