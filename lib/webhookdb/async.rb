# frozen_string_literal: true

require "redis"
require "appydays/configurable"
require "appydays/loggable"
require "sidekiq"
require "sidekiq-cron"

require "webhookdb"

# Remove this when this is fixed:
# https://github.com/ondrejbartas/sidekiq-cron/issues/286
Redis.exists_returns_integer = false

# Host module and namespace for the Webhookdb async jobs system.
#
# The async job system is mostly decoupled into a few parts,
# so we can understand them in pieces.
# Those pieces are: Publish, Model Events, Subscribe, Event Jobs, Routing, and Scheduled Jobs.
#
# Under the hood, the async job system uses Sidekiq.
# Sidekiq is a background job system that persists its data in Redis.
# Worker processes process the jobs off the queue.
#
# Publish
#
# The Webhookdb module has a very basic pub/sub system.
# You can use `Webhookdb.publish` to broadcast an event (event name and payload),
# and register subscribers to listen to the event.
# The actual event exchanged is a Webhookdb::Event, which is a simple wrapper object.
#
#   Webhookdb.publish('webhookdb.auth.failed', email: params[:email])
#
# Model Events
#
# Webhookdb::Postgres::Model types will automatically emit events on create, update, and destroy.
# Most jobs should respond to these events.
#
# It's relatively rare to publish events directly.
#
# Subscribe
#
# Calling Webhookdb::Async.register_subscriber registers a hook that listens for events published
# via Webhookdb.publish. All the subscriber does is send the events to the Router job.
#
# The subscriber should be enabled on clients that should emit events (so all web processes,
# console work that should have side effects like sending emails, and worker processes).
#
# Note that enabling the subscriber on worker processes means that it would be possible
# for a job to end up in an infinite loop
# (imagine if the audit logger, which records all published events, published an event).
# This is expected; be careful of infinite loops!
#
# Event Jobs
#
# The webhookdb/async package contains the actual jobs,
# which must `include Webhookdb::Async::Job`.
# As per best-practices when writing works, keep them as simple as possible,
# and put the business logic elsewhere.
#
# Standard jobs, which we call event-based jobs, generally respond to published events.
# Use the `on` method to define a glob pattern that is matched against event names:
#
#   class Webhookdb::Async::CustomerMailer
#     include Webhookdb::Async::Job
#     on 'webhookdb.customer.created'
#     def _perform(event)
#       customer_id = event.payload.first
#       # Send welcome email
#     end
#   end
#
# The 'on' pattern can be 'webhookdb.customer.*' to match all customer events for example,
# or '*' to match all events. The rules of matching follow File.fnmatch.
#
# Jobs must implement a `_perform` method, which takes a Webhookdb::Event.
# Note that normal Sidekiq workers use a 'perform' method that takes a variable number of arguments;
# the base Async::Job class has this method and delegates its business logic to the subclass _perform method.
#
# Routing
#
# There are two special workers that are important for the overall functioning of the system
# (and do not inherit from Job but rather than Sidekiq::Worker so they are not classified and treated as 'Jobs').
#
# The first is the AuditLogger, which is a basic job that logs all async events.
# This acts as a useful change log for the state of the database.
#
# The second special worker is the Router, which calls `perform` on the event Jobs
# that match the routing information, as explained in Jobs.
# It does this by filtering through all event-based jobs and performing the ones with a route match.
#
# Scheduled Jobs
#
# Scheduled jobs use the sidekiq-cron package: https://github.com/ondrejbartas/sidekiq-cron
# There is a separate base class, Webhookdb::Async::ScheduledJob, that takes care of some standard job setup.
#
# To implement a scheduled job, `include Webhookdb::Async::ScheduledJob`,
# call the `cron` method, and provide a `_perform` method.
# You can also use an optional `splay` method:
#
#   class Webhookdb::Async::CacheBuster
#     include Webhookdb::Async::ScheduledJob
#     cron '*/10 * * * *'
#     splay 60.seconds
#     def _perform
#       # Bust the cache
#     end
#   end
#
# This code will run once every 10 minutes or so (check out https://crontab.guru/ for testing cron expressions).
# The "or so" refers to the _splay_, which is a 'fuzz factor' of how close to the target interval
# the job may run. So in reality, this job will run every 9 to 11 minutes, due to the 60 second splay.
# Splay exists to avoid a "thundering herd" issue.
# Splay defaults to 30s; you may wish to always provide splay, whatever you think for your job.
#
module Webhookdb::Async
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities

  # Registry of all jobs that will be required when the async system is started/run.
  JOBS = [
    "webhookdb/jobs/backfill",
    "webhookdb/jobs/create_mirror_table",
    "webhookdb/jobs/emailer",
    "webhookdb/jobs/message_dispatched",
    "webhookdb/jobs/process_webhook",
    "webhookdb/jobs/send_invite",
    "webhookdb/jobs/reset_code_create_dispatch",
    "webhookdb/jobs/twilioscheduledbackfill",
  ].freeze

  require "webhookdb/async/job_logger"
  require "webhookdb/async/audit_logger"
  require "webhookdb/async/router"

  configurable(:async) do
    # The number of (Float) seconds that should be considered "slow" for a job.
    # Jobs that take longer than this amount of time will be logged
    # at `warn` level.
    setting :slow_job_seconds, 1.0

    setting :sidekiq_redis_url, "redis://localhost:6379/0", key: "REDIS_URL"
    setting :sidekiq_redis_provider, ""

    after_configured do
      # Very hard to to test this, so it's not tested.
      url = self.sidekiq_redis_provider.present? ? ENV[self.sidekiq_redis_provider] : self.sidekiq_redis_url
      redis_params = {url: url}
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
        config.error_handlers << Raven::Sidekiq::ErrorHandler.new
        config.death_handlers << Webhookdb::Async::JobLogger.method(:death_handler)
      end

      Sidekiq.configure_client do |config|
        config.redis = redis_params
      end
    end
  end

  # If true, perform event work synchronously rather than asynchronously.
  # Only useful for testing.
  singleton_predicate_accessor :synchronous_mode
  @synchronous_mode = false

  # Array of all Job subclasses.
  singleton_attr_reader :jobs
  @jobs = []

  # Return an array of all Job subclasses that respond to event publishing (have patterns).
  def self.event_jobs
    return self.jobs.select(&:event_job?)
  end

  # Return an array of all Job subclasses that are scheduled (have intervals).
  def self.scheduled_jobs
    return self.jobs.select(&:scheduled_job?)
  end

  def self.require_jobs
    JOBS.each { |j| require(j) }
  end

  # Register a Webhookdb subscriber that will publish events to Sidekiq/Redis,
  # for future routing.
  def self.register_subscriber
    return Webhookdb.register_subscriber do |ev|
      self._subscriber(ev)
    end
  end

  def self._subscriber(event)
    event_json = event.as_json
    Webhookdb::Async::AuditLogger.perform_async(event_json)
    Webhookdb::Async::Router.perform_async(event_json)
  end

  # Start the scheduler.
  # This should generally be run in the Sidekiq worker process,
  # not a webserver process.
  def self.start_scheduler
    hash = self.scheduled_jobs.each_with_object({}) do |job, memo|
      self.logger.info "Scheduling %s every %p" % [job.name, job.cron_expr]
      memo[job.name] = {
        "class" => job.name,
        "cron" => job.cron_expr,
      }
    end
    load_errs = Sidekiq::Cron::Job.load_from_hash hash
    raise "Errors loading sidekiq-cron jobs: %p" % [load_errs] if load_errs.present?
  end
end
