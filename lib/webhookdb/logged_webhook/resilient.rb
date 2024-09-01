# frozen_string_literal: true

class Webhookdb::LoggedWebhook::Resilient
  def logger = Webhookdb::LoggedWebhook.logger

  def database_urls = Webhookdb::LoggedWebhook.available_resilient_database_urls

  def insert(kwargs)
    return Webhookdb::LoggedWebhook.dataset.insert(kwargs)
  rescue Sequel::DatabaseError => e
    service_integration_opaque_id = kwargs.fetch(:service_integration_opaque_id)
    str_payload = JSON.dump(kwargs)
    self.database_urls.each do |url|
      next unless self.write_to(url, service_integration_opaque_id, str_payload)
      self.logger.warn "resilient_insert_handled", self._dburl_log_kwargs(url), e
      return true
    end
    self.logger.error "resilient_insert_unhandled", {logged_webhook_kwargs: kwargs}, e
    raise
  end

  def write_to(dburl, service_integration_opaque_id, str_payload)
    tblname = Webhookdb::LoggedWebhook.resilient_table_name
    Sequel.connect(dburl, single_threaded: true) do |db|
      begin
        db.create_table?(tblname.to_sym) do
          primary_key :pk
          text :service_integration_opaque_id
          text :json_payload
        end
      rescue Sequel::UniqueConstraintViolation
        # We cannot avoid this race condition. If needed, we can optimize this, but it's a pain
        # so don't worry about it for now.
        nil
      end
      db.from(tblname).insert(service_integration_opaque_id:, json_payload: str_payload)
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
    tblname = Webhookdb::LoggedWebhook.resilient_table_name
    begin
      Webhookdb::LoggedWebhook.db.execute("SELECT 1=1")
    rescue Sequel::DatabaseError
      self.logger.debug("resilient_replay_primary_db_not_ready")
      return nil
    end
    replayed = 0
    self.database_urls.each do |url|
      Sequel.connect(url) do |rdb|
        has_more = true
        # Keep track of the last pk we've replayed, so we can grab the next available one.
        # Otherwise we can end up spinning on the same one, especially with other threads.
        seen_pk = 0
        while has_more
          # Each row must be processed in a transaction
          rdb.transaction do
            row = rdb.from(tblname).where { pk > seen_pk }.for_update.skip_locked.order(:pk).limit(1).first
            if row.nil?
              has_more = false
              break # The break only works for the transaction
            end
            pk = row.fetch(:pk)
            seen_pk = pk
            payload = JSON.parse(row.fetch(:json_payload))
            # We replay the webhook from a separate job
            # so it can be done idempotently/exclusively.
            lwh = Webhookdb::LoggedWebhook.create(payload)
            lwh.replay_async
            replayed += 1
            rdb.from(tblname).where(pk:).delete
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
