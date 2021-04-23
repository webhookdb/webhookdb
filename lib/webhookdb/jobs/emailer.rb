# frozen_string_literal: true

require "webhookdb/async/scheduled_job"

class Webhookdb::Async::Emailer
  extend Webhookdb::Async::ScheduledJob

  cron "* * * * *"
  splay 5.seconds

  def _perform
    self.logger.info "Sending pending emails"
    Webhookdb::Message.send_unsent
  end
end
