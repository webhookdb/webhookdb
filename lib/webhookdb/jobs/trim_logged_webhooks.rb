# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::TrimLoggedWebhooks
  extend Webhookdb::Async::ScheduledJob

  cron "17 8 * * *"
  splay 300

  def _perform
    Webhookdb::LoggedWebhook.trim
  end
end
