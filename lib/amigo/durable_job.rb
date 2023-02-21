# frozen_string_literal: true

require "appydays/configurable"
require "sequel"
require "sidekiq"
require "sidekiq/api"
require "sidekiq/component"

module Amigo
  # This is a placeholder until it's migrated to Amigo proper
end

# Durable jobs keep track of the job in a database, similar to DelayedJob,
# so that if Sidekiq loses the job (because Redis crashes, or the worker crashes),
# it will be sent to the Dead Set from the database.
#
# We send 'missing' jobs to the Dead Set, rather than re-enqueue them,
# because jobs may be deleted out of Redis manually,
# so any re-enqueues of a missing job must also be done manually.
#
# An alternative to durable jobs is super_fetch using something like Redis' LMOVE;
# however the only off-the-shelf package we could find (from Gitlab) did not work well.
# We could implement our own LMOVE based fetch strategy,
# but using PG was a lot simpler to get going (selection is easier, for example, than managing Redis sorted sets).
#
# The way Durable Jobs works at a high level is:
#
# - Connections to a series of database servers are held.
#   These servers act as the 'durable stores' for Redis.
# - In client middleware,
#   a row is written into the first available durable store database.
#   Every row records when it should be considered "dead";
#   that is, after this time,
#   DurableJob moves this job to the Dead Set, as explained below.
#   This is known as the "assume dead at" time; the difference between when a job is enqueued/runs,
#   and when it can be assumed dead, is known as the "heartbeat extension".
# - Whenever the job runs, server middleware takes a lock on the durable store row,
#   and updates assume_dead_at to be "now plus heartbeat_extension".
#   This is true when the job runs the first time, but also during any retry.
# - Any long-running jobs should be sure to call DurableJob.heartbeat
#   to extend the assume_dead_at, so we don't attempt to enqueue another instance
#   of the job (actually we probably won't end up with duplicate jobs,
#   but it's a good optimization).
# - If the job succeeds, the row is deleted from the durable store.
# - If the job errors, assume_dead_at is updated, and the row remains in the durable store.
#
# That is the behavior of the durable jobs themselves.
# The other key piece here is a poller. The poller must use a separate periodic mechanism,
# like sidekiq-cron or whatever. Some number of minutes, `Amigo::DurableJob.poll_jobs` must be called.
# `poll_jobs` does the following at a high level (see the source for more details):
#
# - Look through each durable store database.
# - For each job with an assume_dead_at in the past, we need to check whether we should kill it.
# - If the job is currently processing in a queue, we no-op.
#   We warn that the job should have a longer heartbeat_extension,
#   or something should call DurableJob.heartbeat.
# - If the job is currently in the retry set, we update the assume_dead_at of the row
#   so it's after the time the job will be retried. That way we won't try and process
#   the job again until after it's been retried.
# - If the job is in the DeadSet, we delete the row since it's already dead.
# - If the job cannot be found in any of these places, it's added to the DeadSet.
#
# Note that DurableJob is subject to race conditions,
# and a job can be enqueued and then run multiple times.
# This is an expected part of Sidekiq- your jobs should already
# be idempotent so this race should not be an issue.
# There are (hopefully) no situations where the race condition
# will result in jobs being lost, just processed multiple times.
#
module Amigo::DurableJob
  include Appydays::Configurable
  extend Sidekiq::Component

  def self.included(cls)
    cls.extend ClassMethods
  end

  class << self
    attr_accessor :storage_database_urls, :storage_databases, :table_fqn, :failure_notifier

    # Set a field on the underlying storage databases,
    # such as :logger or :sql_log_level.
    # This value is set immediately on all storage databases,
    # and persists across resets.
    # NOTE: Some fields, like max_connections, can only be set on connect.
    # Use replace_database_settings for this instead.
    def set_database_setting(key, value)
      @database_settings ||= {}
      @database_settings[key] = value
      self.storage_databases.each { |db| db.send("#{key}=", value) }
    end

    # Reconnect to all databases using the given settings.
    # Settings persist across resets.
    def replace_database_settings(new_settings)
      @database_settings = new_settings
      self.reconnect
    end

    def reconnect
      self.storage_databases&.each(&:disconnect)
      settings = @database_settings || {}
      self.storage_databases = self.storage_database_urls.map do |url|
        Sequel.connect(
          url,
          keep_reference: false,
          test: false,
          **settings,
        )
      end
    end

    def ensure_jobs_tables(drop: false)
      self.storage_databases.map do |db|
        db.drop_table?(self.table_fqn) if drop
        db.create_table(self.table_fqn, if_not_exists: true) do
          # Acts as primary key
          text :job_id, null: false, unique: true
          # Class name, pulled out of the item json for convenience
          text :job_class, null: false
          # Smaller footprint than jsonb, and we don't need to use json operators
          text :job_item_json, null: false
          # We must store this so we know where to look for the job
          # NOTE: If a job were to change queues, this *may* cause an issue.
          # But it is hard to test, and we're unlikely to see it, AND in the worst case
          # it'd be a duplicate job, none of which seem critical to solve for now.
          text :queue, null: false
          timestamptz :inserted_at, null: false, default: Sequel.function(:now)
          # Set this so we know when we should check for a dead worker
          # This must always be set, since if the worker to get the job segfaults
          # after taking the job, but before locking it, it will sit empty.
          timestamptz :assume_dead_at, null: false
          # We may need to index this, but since it's a write-heavy table,
          # that should not get so big, let's leave it out for now.
          # index :assume_dead_at

          # Worker performing the job
          text :locked_by
          # Set when a worker takes a job
          timestamptz :locked_at
        end
      end
    end

    def storage_datasets
      return self.storage_databases.map { |db| db[self.table_fqn] }
    end

    def insert_job(job_class, job_id, item, queue: "default", more: {})
      raise Webhookdb::InvalidPrecondition, "not enabled" unless  self.enabled?
      item = item.dup
      item["class"] = job_class.to_s
      job_run_at = item.key?("at") ? Time.at(item["at"]) : Time.now
      assume_dead_at = job_run_at + job_class.heartbeat_extension
      inserted = self.storage_datasets.any? do |ds|
        begin
          ds.
            insert_conflict(
              target: :job_id,
              update: {assume_dead_at:},
            ).insert(
              job_id:,
              job_class: job_class.to_s,
              job_item_json: item.to_json,
              assume_dead_at:,
              # We cannot use get_sidekiq_options, since that is static. We need to pass in the queue,
              # which can be set dynamically.
              queue:,
              **more,
            )
        rescue Sequel::DatabaseConnectionError => e
          # Once this is in Amigo, use its logging system
          Sidekiq.logger.warn "DurableJob: #{job_class}: insert failed: #{e}"
          next
        end
        true
      end
      return if inserted
      Sidekiq.logger.error "DurableJob: #{job_class}: no database available to insert"
    end

    def lock_job(job_id, heartbeat_extension)
      raise Webhookdb::InvalidPrecondition, "not enabled" unless  self.enabled?
      self.storage_datasets.each do |ds|
        begin
          row = ds[job_id:]
        rescue Sequel::DatabaseConnectionError
          next nil
        end
        next nil if row.nil?
        now = Time.now
        new_fields = {
          locked_by: self.identity,
          locked_at: now,
          assume_dead_at: now + heartbeat_extension,
        }
        row.merge!(new_fields)
        ds.where(job_id:).update(**new_fields)
        return [ds, row]
      end
      return nil
    end

    def unlock_job(dataset, job_id, heartbeat_extension)
      dataset.where(job_id:).update(locked_by: nil, locked_at: nil, assume_dead_at: Time.now + heartbeat_extension)
    end

    def heartbeat(now: nil)
      return unless self.enabled?
      now ||= Time.now
      active_worker, ds = Thread.current[:durable_job_active_job]
      return nil if active_worker.nil?
      assume_dead_at = now + active_worker.class.heartbeat_extension
      ds.where(job_id: active_worker.jid).update(assume_dead_at:)
      return assume_dead_at
    end

    def heartbeat!(now: nil)
      return unless self.enabled?
      assume_dead_at = self.heartbeat(now:)
      return assume_dead_at if assume_dead_at
      raise "DurableJob.heartbeat called but no durable job is in TLS"
    end

    def poll_jobs(now: Time.now, skip_queue_size: 500, max_page_size: 2000)
      return unless self.enabled?
      # There is a global retry set we can use across all queues.
      # If it's too big, don't bother polling jobs.
      # Note, this requires we don't let our retry set grow too large...
      retryset = Sidekiq::RetrySet.new
      if retryset.size >= skip_queue_size
        Sidekiq.logger.warn "DurableJob: poll_jobs_retry_set_too_large"
        return
      end
      deadset = Sidekiq::DeadSet.new
      if deadset.size >= skip_queue_size
        Sidekiq.logger.warn "DurableJob: poll_jobs_dead_set_too_large"
        return
      end
      retries_by_jid = retryset.to_h { |r| [r.jid, r] }
      deadset_jids = Set.new(deadset.map(&:jid))
      class_cache = {}
      self.storage_datasets.each do |ds|
        # To avoid big memory usage, process a limited number of items.
        all_rows_to_check = ds.where { assume_dead_at <= now }.
          select(:job_id, :job_class, :queue, :job_item_json).
          order(:assume_dead_at).
          limit(max_page_size).
          all
        if all_rows_to_check.size == max_page_size
          # Hard to imagine this happening but here we are
          Sidekiq.logger.warn "DurableJob: poll_jobs_max_page_size_reached"
        end
        # All our expired rows belong to one of any number of queues.
        # We should process grouped by queue so we only need to look through each queue once.
        by_queues = all_rows_to_check.group_by { |r| r[:queue] }
        by_queues.each do |queue, rows_to_check|
          q = Sidekiq::Queue.new(queue)
          if q.size >= skip_queue_size
            Sidekiq.logger.warn "DurableJob: poll_jobs_queue_size_too_large"
            next
          end
          all_jids_in_queue = Set.new(q.map(&:jid))
          rows_to_check.each do |row|
            job_class = row[:job_class]
            job_id = row[:job_id]
            cls = class_cache[job_class] ||= const_get(job_class)
            dswhere = ds.where(job_id:)
            if all_jids_in_queue.include?(job_id)
              # If a job is in the queue, it means it's processing,
              # and likely has been for a while.
              # In that case, bump the deadline.
              msg = "DurableJob: #{job_class}[#{job_id}] is " \
                    "processing longer than its heartbeat_extension. " \
                    "Consider calling Amigo::DurableJob.heartbeat, " \
                    "or extend Amigo::DurableJob#heartbeat_extension on the job."
              Sidekiq.logger.warn msg
              dswhere.update(assume_dead_at: now + cls.heartbeat_extension)
            elsif (retry_record = retries_by_jid[job_id])
              # If a job is in the retry set, we don't need to bother checking
              # until the retry is ready. If we retry ahead of time, that's fine-
              # if the job succeeds, it'll delete the row, if it fails,
              # it'll overwrite assume_dead_at and we'll get back here.
              Sidekiq.logger.debug "DurableJob: #{job_class}[#{job_id}] is in retry set"
              dswhere.update(assume_dead_at: retry_record.at + cls.heartbeat_extension)
            elsif deadset_jids.include?(job_id)
              # If a job moved to the dead set, we can delete the PG row.
              # When we do the retry from the dead set, it'll push a new job to PG.
              Sidekiq.logger.info "DurableJob: #{job_class}[#{job_id}] is in dead set"
              dswhere.delete
            else
              # The job isn't actively processing nor is in the retry/dead set.
              # This means we have lost it, it was never sent to Sidekiq,
              # or it was manually deleted (via Web UI, probably).
              # Add it to the dead set so it can be manually inspected and retried.
              item = Yajl::Parser.parse(row[:job_item_json])
              item["durable_killed_at"] = now
              item["jid"] ||= job_id
              Sidekiq.logger.warn "DurableJob: #{job_class}[#{job_id}] not found, adding to dead set"

              Amigo::DurableJob.failure_notifier&.call(item)
              deadset.kill(item.to_json, notify_failure: Amigo::DurableJob.failure_notifier.nil?)
              dswhere.delete
            end
          end
        end
      end
    end

    def enabled?
      return self.enabled
    end
  end

  configurable(:durable_job) do
    setting :enabled, false

    # Space-separated URLs to write durable jobs into.
    setting :server_urls, [], convert: ->(s) { s.split.map(&:strip) }
    # Server env vars are the names of environment variables whose value are
    # each value for server_urls.
    # Allows you to use dynamically configured servers.
    # Space-separate multiple env vars.
    setting :server_env_vars, ["DATABASE_URL"], convert: ->(s) { s.split.map(&:strip) }

    setting :schema_name, :public, convert: ->(s) { s.to_sym }
    setting :table_name, :durable_jobs, convert: ->(s) { s.to_sym }

    after_configured do
      self.storage_database_urls = self.server_urls.dup
      self.storage_database_urls.concat(self.server_env_vars.filter_map { |e| ENV.fetch(e, nil) })
      self.table_fqn = Sequel[self.schema_name][self.table_name]
      if self.enabled?
        self.reconnect
        self.ensure_jobs_tables
      end
    end
  end

  module ClassMethods
    # Seconds or duration where, if the job is not completed, it should be re-processed.
    # Set this to short for short jobs,
    # and long for long jobs, since they will be re-enqueued
    # if they take longer than this heartbeat_extension.
    # You can also use Amigo::DurableJob.heartbeat (or heartbeat!)
    # to push the heartbeat_extension time further out.
    # @return [Integer,ActiveSupport::Duration]
    def heartbeat_extension
      return 5.minutes
    end
  end

  class ClientMiddleware
    def call(worker_class, job, queue, _redis_pool)
      return job unless Amigo::DurableJob.enabled?
      (worker_class = worker_class.constantize) if worker_class.is_a?(String)
      return job unless worker_class.respond_to?(:heartbeat_extension)
      Amigo::DurableJob.insert_job(worker_class, job.fetch("jid"), job, queue:) unless job["durable_reenqueued_at"]
      return job
    end
  end

  class ServerMiddleware
    def call(worker, _job, _queue)
      return yield unless Amigo::DurableJob.enabled? && worker.class.respond_to?(:heartbeat_extension)
      ds, row = Amigo::DurableJob.lock_job(worker.jid, worker.class.heartbeat_extension)
      if row.nil?
        Sidekiq.logger.error "DurableJob: #{worker.class}[#{worker.jid}]: no row found in database"
        return yield
      end
      Thread.current[:durable_job_active_job] = worker, ds
      # rubocop:disable Lint/RescueException
      begin
        yield
      rescue Exception
        Amigo::DurableJob.unlock_job(ds, worker.jid, worker.class.heartbeat_extension)
        raise
      ensure
        Thread.current[:durable_job_active_job] = nil
      end
      # rubocop:enable Lint/RescueException
      ds.where(job_id: row[:job_id]).delete
    end
  end
end
