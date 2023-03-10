# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"
require "webhookdb/sponsy"

class Webhookdb::Jobs::SponsyScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron(Webhookdb::Sponsy.cron_expression)
  splay 1.minute

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "sponsy_publication_v1") do |sint|
      sint.publish_immediate("backfill", sint.id, {cascade: true, incremental: true})
    end
  end
end
