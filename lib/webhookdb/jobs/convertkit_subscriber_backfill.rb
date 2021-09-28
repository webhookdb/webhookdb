# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::ConvertKitSubscriberBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "*/60 * * * * *"
  splay 30

  def _perform
    Webhookdb::ServiceIntegration.dataset.where_each(service_name: "convertkit_subscriber_v1") do |sint|
      sint.publish_immediate("backfill", sint.id)
    end
  end
end
