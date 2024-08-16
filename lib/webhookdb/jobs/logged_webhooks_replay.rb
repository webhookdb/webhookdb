# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::LoggedWebhooksReplay
  extend Webhookdb::Async::Job

  on "webhookdb.loggedwebhook.replay"

  def _perform(event)
    lwh = self.lookup_model(Webhookdb::LoggedWebhook, event)
    self.with_log_tags(service_integration_opaque_id: lwh.service_integration_opaque_id) do
      lwh.retry_one(truncate_successful: true)
    end
  end
end
