# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::DemoModeSyncData
  extend Webhookdb::Async::Job

  on "webhookdb.organization.syncdemodata"

  def _perform(event)
    org = self.lookup_model(Webhookdb::Organization, event)
    if org.admin_connection_url.blank?
      # If PrepareDatabaseConnections hasn't run, we can't sync yet.
      # Retry every 1 second for a couple minutes until we have a database.
      raise Amigo::Retry::OrDie.new(120, 1)
    end
    Webhookdb::DemoMode.sync_demo_data(org)
  end
end
