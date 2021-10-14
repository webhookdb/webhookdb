# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::TwilioScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "*/60 * * * * *"
  splay 0

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "twilio_sms_v1") do |sint|
      sint.publish_immediate("backfill", sint.id, {incremental: true})
    end
  end
end
