# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Async::CreateMirrorTable
  extend Webhookdb::Async::Job

  on "webhookdb.serviceintegration.created"

  def _perform(event)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
    svc = Webhookdb::Services.service_instance(sint)
    svc.create_table
  end
end
