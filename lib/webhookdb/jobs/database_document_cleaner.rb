# frozen_string_literal: true

require "webhookdb/async/scheduled_job"

class Webhookdb::Jobs::DatabaseDocumentCleaner
  extend Webhookdb::Async::ScheduledJob

  cron "*/10 * * * *"
  splay 5

  def _perform
    Webhookdb::DatabaseDocument.clean_old_documents(now: Time.now)
  end
end
