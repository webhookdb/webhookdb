# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::Backfill
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.backfill"
  sidekiq_options queue: "netout"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event.payload[0])
    svc = Webhookdb::Services.service_instance(sint)
    svc.ensure_all_columns
    backfill_kwargs = event.payload[1] || {}
    svc.backfill(**backfill_kwargs.symbolize_keys)
  end
end
