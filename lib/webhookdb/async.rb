# frozen_string_literal: true

require "amigo/retry"
require "amigo/durable_job"
require "amigo/rate_limited_error_handler"
require "appydays/configurable"
require "appydays/loggable"
require "sentry-sidekiq"
require "sidekiq"
require "sidekiq-cron"

Sidekiq.strict_args!

require "webhookdb"

module Webhookdb::Async
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  # Registry of all jobs that will be required when the async system is started/run.
  JOBS = [
    "webhookdb/jobs/amigo_test_jobs",
    "webhookdb/jobs/backfill",
    "webhookdb/jobs/convertkit_broadcast_backfill",
    "webhookdb/jobs/convertkit_subscriber_backfill",
    "webhookdb/jobs/convertkit_tag_backfill",
    "webhookdb/jobs/create_mirror_table",
    "webhookdb/jobs/create_stripe_customer",
    "webhookdb/jobs/customer_created_notify_internal",
    "webhookdb/jobs/deprecated_jobs",
    "webhookdb/jobs/developer_alert_handle",
    "webhookdb/jobs/durable_job_recheck_poller",
    "webhookdb/jobs/emailer",
    "webhookdb/jobs/message_dispatched",
    "webhookdb/jobs/organization_database_migration_notify_finished",
    "webhookdb/jobs/organization_database_migration_notify_started",
    "webhookdb/jobs/organization_database_migration_run",
    "webhookdb/jobs/process_webhook",
    "webhookdb/jobs/prepare_database_connections",
    "webhookdb/jobs/replication_migration",
    "webhookdb/jobs/send_invite",
    "webhookdb/jobs/send_webhook",
    "webhookdb/jobs/send_test_webhook",
    "webhookdb/jobs/sync_target_enqueue_scheduled",
    "webhookdb/jobs/sync_target_run_sync",
    "webhookdb/jobs/reset_code_create_dispatch",
    "webhookdb/jobs/sponsy_scheduled_backfill",
    "webhookdb/jobs/theranest_scheduled_backfill",
    "webhookdb/jobs/transistor_episode_backfill",
    "webhookdb/jobs/trim_logged_webhooks",
    "webhookdb/jobs/twilio_scheduled_backfill",
    "webhookdb/jobs/webhook_resource_notify_integrations",
  ].freeze

  require "webhookdb/async/job_logger"
  require "webhookdb/async/audit_logger"

  configurable(:async) do
    # The number of (Float) seconds that should be considered "slow" for a job.
    # Jobs that take longer than this amount of time will be logged
    # at `warn` level.
    setting :slow_job_seconds, 1.0

    setting :sidekiq_redis_url, "redis://localhost:6379/0", key: "REDIS_URL"
    setting :sidekiq_redis_provider, ""
    # For sidekiq web UI. Randomize a default so they will only be useful if set.
    setting :web_username, SecureRandom.hex(8)
    setting :web_password, SecureRandom.hex(8)

    setting :error_reporting_sample_rate, 0.1
    setting :error_reporting_ttl, 120

    after_configured do
      # Very hard to to test this, so it's not tested.
      url = self.sidekiq_redis_provider.present? ? ENV.fetch(self.sidekiq_redis_provider, nil) : self.sidekiq_redis_url
      redis_params = {url:}
      if url.start_with?("rediss:") && ENV["HEROKU_APP_ID"]
        # rediss: schema is Redis with SSL. They use self-signed certs, so we have to turn off SSL verification.
        # There is not a clear KB on this, you have to piece it together from Heroku and Sidekiq docs.
        redis_params[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE}
      end
      Sidekiq.configure_server do |config|
        config.redis = redis_params
        config.options[:job_logger] = Webhookdb::Async::JobLogger
        # We do NOT want the unstructured default error handler
        config.error_handlers.replace([Webhookdb::Async::JobLogger.method(:error_handler)])
        # We must then replace the otherwise-automatically-added sentry middleware
        config.error_handlers << Amigo::RateLimitedErrorHandler.new(
          Sentry::Sidekiq::ErrorHandler.new,
          sample_rate: self.error_reporting_sample_rate,
          ttl: self.error_reporting_ttl,
        )
        config.death_handlers << Webhookdb::Async::JobLogger.method(:death_handler)
        config.server_middleware.add(Amigo::DurableJob::ServerMiddleware)
        # We use the dead set to move jobs that we need to retry manually
        config.options[:dead_max_jobs] = 999_999_999
        config.server_middleware.add(Amigo::Retry::ServerMiddleware)
      end

      Sidekiq.configure_client do |config|
        config.redis = redis_params
        config.client_middleware.add(Amigo::DurableJob::ClientMiddleware)
      end
    end
  end

  def self.open_web
    u = URI(Webhookdb.api_url)
    u.user = self.web_username
    u.password = self.web_password
    u.path = "/sidekiq"
    `open #{u}`
  end

  # Set up async for the web/client side of things.
  # This performs common Amigo config,
  # and sets up the routing/auditing jobs.
  #
  # Note that we must also require all async jobs,
  # since in some cases we may have sidekiq middleware that needs
  # access to the actual job class, so it must be available.
  def self.setup_web
    self._setup_common
    Amigo.install_amigo_jobs
    self._require_jobs
    return true
  end

  # Set up the worker process.
  # This peforms common Amigo config,
  # sets up the routing/audit jobs (since jobs may publish to other jobs),
  # requires the actual jobs,
  # and starts the cron.
  def self.setup_workers
    self._setup_common
    Amigo.install_amigo_jobs
    self._require_jobs
    Amigo.start_scheduler
    return true
  end

  # Set up for tests.
  # This performs common config and requires the jobs.
  # It does not install the routing/auditing jobs,
  # since those should only be installed at specific times.
  def self.setup_tests
    return if Amigo.structured_logging # assume we are set up
    self._setup_common
    self._require_jobs
    return true
  end

  def self._require_jobs
    Amigo::DurableJob.replace_database_settings(
      loggers: [Webhookdb.logger],
      **Webhookdb::Dbutil.configured_connection_options,
    )
    JOBS.each { |j| require(j) }
  end

  def self._setup_common
    raise "Async already setup, only call this once" if Amigo.structured_logging
    Amigo.structured_logging = true
    Amigo.log_callback = lambda { |j, lvl, msg, o|
      lg = j ? Appydays::Loggable[j] : Webhookdb::Async::JobLogger.logger
      lg.send(lvl, msg, o)
    }
  end
end

require "webhookdb/async/audit_logger"
Amigo.audit_logger_class = Webhookdb::Async::AuditLogger
