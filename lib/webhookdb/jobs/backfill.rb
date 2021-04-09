# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::Backfill
  extend Webhookdb::Async::Job

  on "webhookdb.service.backfill"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    svc = Webhookdb::Services.service_instance(sint)
    svc.backfill
  end
end
