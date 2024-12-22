# frozen_string_literal: true

require "amigo/semaphore_backoff_job"

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::IcalendarSync
  extend Webhookdb::Async::Job
  include Amigo::SemaphoreBackoffJob

  sidekiq_options retry: false, queue: "netout"

  def perform(sint_id, calendar_external_id)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, sint_id)
    self.set_job_tags(sint.log_tags.merge(calendar_external_id:))
    row = sint.replicator.admin_dataset { |ds| ds[external_id: calendar_external_id] }
    if row.nil?
      self.set_job_tags(result: "icalendar_sync_row_miss")
      return
    end
    self.logger.debug("icalendar_sync_start")
    sint.replicator.sync_row(row)
    self.set_job_tags(result: "icalendar_synced")
  end

  def before_perform(sint_id, *)
    @sint = self.lookup_model(Webhookdb::ServiceIntegration, sint_id)
  end

  def semaphore_key = "semaphore-icalendarsync-#{@sint.organization_id}"
  def semaphore_size = @sint.organization.job_semaphore_size
  def semaphore_expiry = 15.minutes
  def semaphore_backoff = 60 + (rand * 30)
end
