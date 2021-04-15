# frozen_string_literal: true

require "webhookdb/async/scheduled_job"
require "webhookdb/jobs"

class Webhookdb::Jobs::TwilioScheduledBackfill
  extend Webhookdb::Async::ScheduledJob

  cron "*/10 * * * * *"
  splay 10.seconds

  def _perform
    # uses the fake service in test mode so that we can mock backfill responses
    service_name = if ENV["SERVICE_DEVMODE"]
                     "fake_v1"
    else
      "twilio_sms_v1"
                   end

    Webhookdb::ServiceIntegration.dataset.where_each(service_name: service_name) do |sint|
      svc = Webhookdb::Services.service_instance(sint)
      svc.backfill
    end
  end
end
