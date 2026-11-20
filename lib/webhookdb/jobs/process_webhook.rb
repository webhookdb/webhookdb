# frozen_string_literal: true

require "amigo/durable_job"
require "amigo/queue_backoff_job"
require "amigo/semaphore_backoff_job"
require "webhookdb/async/job"
require "webhookdb/async/resilient_sidekiq_client"

class Webhookdb::Jobs::ProcessWebhook
  extend Webhookdb::Async::Job
  include Amigo::DurableJob
  include Amigo::QueueBackoffJob
  include Amigo::SemaphoreBackoffJob

  on "webhookdb.serviceintegration.webhook"
  sidekiq_options(
    queue: "webhook", # This is usually overridden
    client_class: Webhookdb::Async::ResilientSidekiqClient,
  )

  def dependent_queues = ["critical"]
  def semaphore_expiry = 5.minutes.to_i
  def semaphore_key = "semaphore-procwebhook-#{@sint.job_semaphore_identifier}"
  def semaphore_size = @sint.job_semaphore_size

  def before_perform(*args)
    event = Amigo::Event.from_json(args[0])
    @sint = self.lookup_model(Webhookdb::ServiceIntegration, event)
  end

  def _perform(event)
    self.set_job_tags(@sint.log_tags)
    kw = event.payload[1].symbolize_keys
    svc = Webhookdb::Replicator.create(@sint)
    # kwargs contains: :headers, :body, :request_path, :request_method
    req = Webhookdb::Replicator::WebhookRequest.new(
      body: kw.fetch(:body),
      headers: kw.fetch(:headers),
      path: kw.fetch(:request_path),
      method: kw.fetch(:request_method),
    )
    svc.upsert_webhook(req)
  end
end
