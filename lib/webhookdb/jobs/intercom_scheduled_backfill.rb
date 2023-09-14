# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/intercom"

class Webhookdb::Jobs::IntercomScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "*/1 * * * *"
  splay 5.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "intercom_marketplace_root_v1") do |sint|
      Webhookdb::BackfillJob.create_recursive(service_integration: sint, incremental: false).enqueue
    end
  end
end
