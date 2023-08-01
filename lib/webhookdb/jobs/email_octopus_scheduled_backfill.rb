# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/email_octopus"

class Webhookdb::Jobs::EmailOctopusScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron(Webhookdb::EmailOctopus.cron_expression)
  splay 5.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "email_octopus_list_v1") do |sint|
      Webhookdb::BackfillJob.create_recursive(service_integration: sint, incremental: false).enqueue
    end
  end
end
