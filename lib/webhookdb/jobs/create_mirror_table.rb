# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::CreateMirrorTable
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.created"
  sidekiq_options queue: "critical"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    self.set_job_tags(sint.log_tags)
    svc = Webhookdb::Replicator.create(sint)
    svc.create_table(if_not_exists: true)
  end
end
