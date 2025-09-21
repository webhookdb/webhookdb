# frozen_string_literal: true

require "amigo/durable_job"
require "amigo/queue_backoff_job"
require "amigo/retry"
require "amigo/semaphore_backoff_job"
require "appydays/configurable"
require "appydays/loggable"
require "sentry-sidekiq"
require "sidekiq"
require "sidekiq-cron"

require "webhookdb/redis"

module Webhookdb::Async; end

module Webhookdb::Async
  include Appydays::Configurable
  include Appydays::Loggable

  require "webhookdb/async/job_logger"

  def self._configure_server(config)
    require "amigo/job_in_context"
    require "amigo/rate_limited_error_handler"
    require "webhookdb/async/extended_logging"
    require "webhookdb/async/timeout_retry"
    url = Webhookdb::Redis.fetch_url(self.sidekiq_redis_provider, self.sidekiq_redis_url)
    config.redis = Webhookdb::Redis.conn_params(url)
    config[:job_logger] = Webhookdb::Async::JobLogger
    # We do NOT want the unstructured default error handler
    config.error_handlers.replace([Webhookdb::Async::JobLogger.method(:error_handler)])
    # We must then replace the otherwise-automatically-added sentry middleware
    config.error_handlers << Amigo::RateLimitedErrorHandler.new(
      Sentry::Sidekiq::ErrorHandler.new,
      sample_rate: self.error_reporting_sample_rate,
      ttl: self.error_reporting_ttl,
    )
    config.death_handlers << Webhookdb::Async::JobLogger.method(:death_handler)
    config.server_middleware.add(Webhookdb::Async::ExtendedLogging::ServerMiddleware)
    config.server_middleware.add(Amigo::JobInContext::ServerMiddleware)
    config.server_middleware.add(Amigo::DurableJob::ServerMiddleware)
    # We use the dead set to move jobs that we need to retry manually
    config[:dead_max_jobs] = 999_999_999
    config.server_middleware.add(Amigo::Retry::ServerMiddleware)
    config.server_middleware.add(Webhookdb::Async::TimeoutRetry::ServerMiddleware)

    config.on(:quiet) do
      self.sidekiq_shutting_down = true
    end
  end

  def self._configure_client(config)
    url = Webhookdb::Redis.fetch_url(self.sidekiq_redis_provider, self.sidekiq_redis_url)
    config.redis = Webhookdb::Redis.conn_params(url)
    config.client_middleware.add(Amigo::DurableJob::ClientMiddleware)
  end

  configurable(:async) do
    # The number of (Float) seconds that should be considered "slow" for a job.
    # Jobs that take longer than this amount of time will be logged
    # at `warn` level.
    setting :slow_job_seconds, 1.0

    # The log level that Webhookdb::Async::AuditLogger logs at.
    # By default, use :info, but :debug may be appropriate for higher-activity servers
    # to reduce logging costs (the messages can be big).
    setting :audit_log_level, :info

    setting :sidekiq_redis_url, "redis://localhost:6379/0", key: "REDIS_URL"
    setting :sidekiq_redis_provider, ""
    # For sidekiq web UI. Randomize a default so they will only be useful if set.
    setting :web_username, SecureRandom.hex(8)
    setting :web_password, SecureRandom.hex(8)

    setting :error_reporting_sample_rate, 0.1
    setting :error_reporting_ttl, 120

    # If true, disable queue backoff and semaphore job behavior.
    # This can be used if there is a large queue of jobs to push through.
    setting :backoff_disabled, false

    after_configured do
      Amigo::DurableJob.failure_notifier = Webhookdb::Async::JobLogger.method(:durable_job_failure_notifier)
      Amigo::QueueBackoffJob.enabled = !Webhookdb::Async.backoff_disabled
      Amigo::SemaphoreBackoffJob.enabled = !Webhookdb::Async.backoff_disabled
      Sidekiq.default_configuration.logger = self.logger
      Sidekiq.configure_server { |config| self._configure_server(config) }
      Sidekiq.configure_client { |config| self._configure_client(config) }
    end
  end

  class << self
    attr_writer :sidekiq_shutting_down

    def stop_processing_jobs? = @sidekiq_shutting_down

    # Call this in long-running jobs.
    # Raises +Sidekiq::Shutdown+ if we're trying to shut down.
    # Emits an +Amigo::DurableJob+ heartbeat if enabled.
    def long_running_job_heartbeat!
      raise Sidekiq::Shutdown if self.stop_processing_jobs?
      Amigo::DurableJob.heartbeat
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
    self.require_jobs
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
    self.require_jobs
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
    self.require_jobs
    return true
  end

  def self.require_jobs
    Amigo::DurableJob.replace_database_settings(
      loggers: [Webhookdb.logger],
      **Webhookdb::Dbutil.configured_connection_options,
    )
    require "webhookdb/jobs"
    Gem.find_files(File.join("webhookdb/jobs/*.rb")).each do |path|
      require path
    end
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
