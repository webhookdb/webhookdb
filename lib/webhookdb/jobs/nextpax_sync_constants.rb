# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/nextpax"

class Webhookdb::Jobs::NextpaxSyncConstants
  extend Webhookdb::Async::ScheduledJob

  cron(Webhookdb::Nextpax.constants_sync_cron_expression)
  splay 10.seconds

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "nextpax_amenity_code_v1") do |sint|
      Webhookdb::BackfillJob.create(service_integration: sint, incremental: true).enqueue
    end
  end
end
