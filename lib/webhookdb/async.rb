# frozen_string_literal: true

require "amigo/retry"
require "amigo/durable_job"
require "amigo/job_in_context"
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

  require "webhookdb/async/job_logger"
  require "webhookdb/async/audit_logger"

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
        config.server_middleware.add(Amigo::JobInContext::ServerMiddleware)
        config.server_middleware.add(Amigo::DurableJob::ServerMiddleware)
        # We use the dead set to move jobs that we need to retry manually
        config.options[:dead_max_jobs] = 999_999_999
        config.server_middleware.add(Amigo::Retry::ServerMiddleware)
      end

      Amigo::DurableJob.failure_notifier = Webhookdb::Async::JobLogger.method(:durable_job_failure_notifier)

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
