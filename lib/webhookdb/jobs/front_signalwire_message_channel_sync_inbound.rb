# frozen_string_literal: true

require "webhookdb/async/job"
require "webhookdb/jobs"

# See +Webhookdb::Replicator::FrontSignalwireMessageChannelAppV1#alert_async_failed_signalwire_send+
# for why we need to pull this into an async job.
class Webhookdb::Jobs::FrontSignalwireMessageChannelSyncInbound
  extend Webhookdb::Async::Job

  def perform(service_integration_id, kwargs)
    sint = self.lookup_model(Webhookdb::ServiceIntegration, service_integration_id)
    sint.replicator.sync_sms_into_front(**kwargs.symbolize_keys)
  end
end
