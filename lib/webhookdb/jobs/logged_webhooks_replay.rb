# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::LoggedWebhooksReplay
  extend Webhookdb::Async::Job

  on "webhookdb.loggedwebhook.replay"

  def _perform(event)
    lwh = self.lookup_model(Webhookdb::LoggedWebhook, event)
    self.set_job_tags(
      logged_webhook_id: lwh.id,
      service_integration_opaque_id: lwh.service_integration_opaque_id,
    )
    lwh.retry_one(truncate_successful: true)
  end
end
