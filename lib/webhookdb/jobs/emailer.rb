# frozen_string_literal: true

require "webhookdb/async/scheduled_job"

class Webhookdb::Jobs::Emailer
  extend Webhookdb::Async::ScheduledJob

  cron "* * * * *"
  splay 5.seconds

  def _perform
    sent = Webhookdb::Message.send_unsent
    self.set_job_tags(sent_messages: sent.count)
  end
end
