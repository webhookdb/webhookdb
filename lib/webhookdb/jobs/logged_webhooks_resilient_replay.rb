# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::LoggedWebhooksResilientReplay
  extend Webhookdb::Async::ScheduledJob

  cron "*/3 * * * *"
  splay 5

  def _perform
    Webhookdb::LoggedWebhook.resilient_replay
  end
end
