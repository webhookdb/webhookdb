# frozen_string_literal: true

require "webhookdb/async/scheduled_job"

class Webhookdb::Jobs::Emailer
  extend Webhookdb::Async::ScheduledJob

  cron "* * * * *"
  splay 5.seconds

  def _perform
    Webhookdb::Message.send_unsent
  end
end
