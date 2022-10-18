# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::CreateMirrorTable
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.created"
  sidekiq_options queue: "critical"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    svc = Webhookdb::Replicator.create(sint)
    svc.create_table
  end
end
