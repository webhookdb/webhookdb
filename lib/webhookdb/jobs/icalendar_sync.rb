# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

class Webhookdb::Jobs::IcalendarSync
  extend Webhookdb::Async::Job

  def perform(sint_id, external_id)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, sint_id)
    self.with_log_tags(sint.log_tags) do
      row = sint.replicator.admin_dataset { |ds| ds[external_id:] }
      if row.nil?
        self.logger.warn("icalendar_sync_row_miss", external_id:)
        return
      end
      sint.replicator.sync_row(row)
    end
  end
end
