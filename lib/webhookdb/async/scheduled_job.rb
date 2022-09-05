# frozen_string_literal: true

require "amigo/scheduled_job"

module Webhookdb::Async::ScheduledJob
  def self.extended(cls)
    cls.extend Amigo::ScheduledJob
  end
end
