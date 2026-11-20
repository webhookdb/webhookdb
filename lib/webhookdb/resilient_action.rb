# frozen_string_literal: true

class Webhookdb::ResilientAction
  # How often are insert exceptions reported to Sentry?
  ERROR_REPORT_INTERVAL = 60

  class << self
    # Capture the exception in Sentry. Rate limit the reporting,
    # since most of the time we will get swarms of failures (database goes down, etc).
    # Rate limits are per-exception-type, so for example we will rate limit Redis and Postgres errors separately;
    # but we don't care about specific databases going down and rate limiting them.
    # Services going down should be exceptional.
    def capture_exception(e, reset: false)
      if reset
        @last_captured_at_hash = nil
        return
      end
      @last_captured_at_hash ||= {}
      last_captured_at = @last_captured_at_hash[e.class] || Time.at(0)
      return if (last_captured_at + ERROR_REPORT_INTERVAL) > Time.now
      @last_captured_at_hash[e.class] = Time.now
      Sentry.capture_exception(e)
    end
  end

  def logger = raise NotImplementedError
  def database_urls = raise NotImplementedError
  def rescued_exception_types = raise NotImplementedError
  def do_insert(_kwargs, _meta) = raise NotImplementedError
  def table_name = raise NotImplementedError
  def ping = raise NotImplementedError
  def do_replay(_kwargs, _meta) = raise NotImplementedError

  def insert(action_kwargs, meta)
    return self.do_insert(action_kwargs, meta)
  rescue StandardError => e
    raise e unless self.rescued_exception_types.any? { |ec| e.is_a?(ec) }
    payload_str = JSON.dump(action_kwargs)
    meta_str = JSON.dump(meta)
    self.database_urls.each do |url|
      next unless self.write_to(url, payload_str, meta_str)
      self.logger.warn "resilient_insert_handled", self._dburl_log_kwargs(url), e
      Webhookdb::ResilientAction.capture_exception(e)
      return true
    end
    self.logger.error "resilient_insert_unhandled", {action_kwargs:, meta:}, e
    raise
  end

  def write_to(dburl, str_payload, str_meta)
    Sequel.connect(dburl, single_threaded: true) do |db|
      begin
        db.create_table?(self.table_name.to_sym) do
          primary_key :pk
          text :json_meta
          text :json_payload
        end
      rescue Sequel::UniqueConstraintViolation
        # We cannot avoid this race condition. If needed, we can optimize this, but it's a pain
        # so don't worry about it for now.
        nil
      end
      db.from(self.table_name.to_sym).insert(json_meta: str_meta, json_payload: str_payload)
    end
    return true
  rescue StandardError => e
    self.logger.debug "resilient_insert_failure", self._dburl_log_kwargs(dburl), e
    return false
  end

  def _dburl_log_kwargs(dburl)
    u = URI(dburl)
    return {fallback_database_host: u.host, fallback_database_name: u.path}
  end

  # - For each (reachable) database:
  # - Select 1 row, with a lock
  # - Replay the webhook
  # - On success, delete the row
  # - On failure, process the next row
  def replay
    begin
      self.ping
    rescue StandardError => e
      raise e unless self.rescued_exception_types.any? { |ec| e.is_a?(ec) }
      self.logger.debug("resilient_replay_primary_db_not_ready")
      return nil
    end
    replayed = 0
    self.database_urls.each do |url|
      Sequel.connect(url) do |rdb|
        has_more = true
        # Keep track of the last pk we've replayed, so we can grab the next available one.
        # Otherwise, we can end up spinning on the same one, especially with other threads.
        seen_pk = 0
        while has_more
          # Each row must be processed in a transaction
          rdb.transaction do
            row = rdb.from(self.table_name.to_sym).where do
              pk > seen_pk
            end.for_update.skip_locked.order(:pk).limit(1).first
            if row.nil?
              has_more = false
              break # The break only works for the transaction
            end
            pk = row.fetch(:pk)
            seen_pk = pk
            payload = JSON.parse(row.fetch(:json_payload))
            meta = JSON.parse(row.fetch(:json_meta))
            self.do_replay(payload, meta)
            replayed += 1
            rdb.from(self.table_name.to_sym).where(pk:).delete
          end
        end
      end
      return replayed
    rescue Sequel::DatabaseError
      self.logger.debug("resilient_replay_fallback_unavailable", **self._dburl_log_kwargs(url))
      return nil
    end
  end
end
