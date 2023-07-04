# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::ConvertkitSubscriberBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "0 20 * * * *"
  splay 5.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "convertkit_subscriber_v1") do |sint|
      Webhookdb::BackfillJob.create(service_integration: sint, incremental: true).enqueue
    end
  end
end
