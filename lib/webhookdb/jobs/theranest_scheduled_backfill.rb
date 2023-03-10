# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/theranest"

class Webhookdb::Jobs::TheranestScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron(Webhookdb::Theranest.cron_expression)
  splay 5.minutes

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "theranest_auth_v1") do |sint|
      sint.publish_immediate("backfill", sint.id, {cascade: true})
    end
  end
end
