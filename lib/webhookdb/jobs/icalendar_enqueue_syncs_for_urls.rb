# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::IcalendarEnqueueSyncsForUrls
  extend Webhookdb::Async::Job

  def perform(urls)
    self.set_job_tags(url_count: urls.length)
    row_count = 0
    Webhookdb::ServiceIntegration.where(service_name: "icalendar_calendar_v1").each do |sint|
      sint.replicator.admin_dataset do |ds|
        affected_row_ext_ids = ds.where(ics_url: urls).select_map(:external_id)
        affected_row_ext_ids.each do |ext_id|
          Webhookdb::Jobs::IcalendarSync.perform_async(sint.id, ext_id)
        end
        row_count += affected_row_ext_ids.length
      end
    end
    self.set_job_tags(result: "icalendar_enqueued_syncs", row_count:)
  end
end
