# frozen_string_literal: true

require "amigo/durable_job"
require "amigo/queue_backoff_job"
require "amigo/semaphore_backoff_job"
require "webhookdb/async/job"

class Webhookdb::Jobs::ProcessWebhook
  extend Webhookdb::Async::Job
  include Amigo::DurableJob
  include Amigo::QueueBackoffJob
  include Amigo::SemaphoreBackoffJob

  on "webhookdb.serviceintegration.webhook"
  sidekiq_options queue: "webhook" # This is usually overridden.

  def dependent_queues
    return ["critical"]
  end

  def before_perform(*args)
    event = Webhookdb::Event.from_json(args[0])
    @sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
  end

  def _perform(event)
    self.with_log_tags(
      service_integration_id: @sint.id,
      service_integration_name: @sint.service_name,
      service_integration_table: @sint.table_name,
    ) do
      kwargs = event.payload[1].symbolize_keys
      svc = Webhookdb::Services.service_instance(@sint)
      svc.upsert_webhook(body: kwargs.fetch(:body))
    end
  end

  def semaphore_key
    return "semaphore-procwebhook-#{@sint.organization_id}"
  end

  def semaphore_size
    return @sint.organization.job_semaphore_size
  end
end
