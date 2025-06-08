# frozen_string_literal: true

require "appydays/configurable"

require "webhookdb/postgres/model"

class Webhookdb::LoggedWebhook < Webhookdb::Postgres::Model(:logged_webhooks)
  include Appydays::Configurable

  class << self
    attr_accessor :available_resilient_database_urls
  end

  configurable(:logged_webhooks) do
    # Space-separated URLs to use for resilient/high availability writes.
    setting :resilient_database_urls, [], convert: ->(s) { s.split.map(&:strip) }
    setting :resilient_database_env_vars, [], convert: ->(s) { s.split.map(&:strip) }
    setting :resilient_webhooks_table_name, "_resilient_logged_webhooks_writes"
    # Using /replay can send this many webhooks in one request.
    # Making this too high can cause timeouts- the caller may have to make multiple calls instead.
    setting :maximum_replay_interval_hours, 4
    # Webhooks this old cannot be replayed; they are probably truncated anyway.
    setting :maximum_replay_history_hours, 7 * 24

    after_configured do
      self.available_resilient_database_urls = self.resilient_database_urls.dup
      self.available_resilient_database_urls.concat(self.resilient_database_env_vars.map { |e| ENV.fetch(e, nil) })
    end
  end

  many_to_one :organization, class: "Webhookdb::Organization"

  many_to_one :service_integration,
              class: "Webhookdb::ServiceIntegration",
              key: :service_integration_opaque_id,
              primary_key: :opaque_id

  DELETE_UNOWNED = 14.days
  DELETE_SUCCESSES = 90.days
  TRUNCATE_SUCCESSES = 7.days
  DELETE_FAILURES = 90.days
  TRUNCATE_FAILURES = 30.days
  # When we retry a request, set this so we know not to re-log it.
  RETRY_HEADER = "Whdb-Logged-Webhook-Retry"
  # When we retry a request, these headers
  # must come from the Ruby client, NOT the original request.
  NONOVERRIDABLE_HEADERS = [
    "Accept-Encoding",
    "Accept",
    "Host",
    "Version",
  ].to_set
  # These headers have been added by Heroku/our web host,
  # so should not be part of the retry.
  WEBHOST_HEADERS = [
    "Connection",
    "Connect-Time",
    "X-Request-Id",
    "X-Forwarded-For",
    "X-Request-Start",
    "Total-Route-Time",
    "X-Forwarded-Port",
    "X-Forwarded-Proto",
    "Via",
  ].to_set

  # Trim logged webhooks to keep this table to a reasonable size.
  # The current trim algorithm and rationale is:
  #
  # - Logs that belong to inserts that were not part of an org are for our internal use only.
  #   They usually indicate an integration that was misconfigured, or is for an org that doesn't exist.
  #   We keep these around for 2 weeks (they are always errors since they have no org).
  #   Ideally we investigate and remove them before that.
  #   We may need to 'block' certain opaque ids from being logged in the future,
  #   if for example we cannot get a client to turn off a misconfigured webhook.
  # - Successful webhooks get their contents (request body and headers)
  #   _truncated_ after 7 days (but the webhook row remains).
  #   Usually we don't need to worry about these so in theory we can avoid logging verbose info at all.
  # - Successful webhooks are deleted entirely after 90 days.
  #   Truncated webhooks are useful for statistics,
  #   but we can remove them earlier in the future.
  # - Failed webhooks get their contents truncated after 30 days,
  #   but the webhook row remains. We have a longer truncation date
  #   so we have more time to investigate.
  # - Error webhooks are deleted entirely after 90 days.
  def self.trim(now: Time.now)
    owned = self.exclude(organization_id: nil)
    unowned = self.where(organization_id: nil)
    successes = owned.where { response_status < 400 }
    failures = owned.where { response_status >= 400 }
    # NOTE: This code is tightly coupled with indices created in 050_logged_webhooks_indices.rb
    # We create a separate index for each operation; the indices (5 in total) cover the full combination of:
    # - rows without an organization (idx 1)
    # - rows with an organization
    #   - rows already truncated
    #     - rows with status < 400 (idx 2)
    #     - rows with status >= 400 (idx 3)
    #   - rows not truncated
    #     - rows with status < 400 (idx 4)
    #     - rows with status >= 400 (idx 5)
    # Note that we only delete already-truncated rows so we can keep our indices smaller;
    # since deletion ages are always older than truncation ages, this should not be a problem.

    # Delete old unowned
    unowned.where { inserted_at < now - DELETE_UNOWNED }.delete
    # Delete successes first so they don't have to be truncated
    successes.where { inserted_at < now - DELETE_SUCCESSES }.exclude(truncated_at: nil).delete
    self.truncate_dataset(successes.where { inserted_at < now - TRUNCATE_SUCCESSES })
    # Delete failures
    failures.where { inserted_at < now - DELETE_FAILURES }.exclude(truncated_at: nil).delete
    self.truncate_dataset(failures.where { inserted_at < now - TRUNCATE_FAILURES })
  end

  # Send instances back in 'through the front door' of this API.
  # Return is a partition of [logs with 2xx responses, others].
  # Generally you can safely call `truncate_logs(result[0])`,
  # or pass in (truncate_successful: true).
  def self.retry_logs(instances, truncate_successful: false)
    successes, failures = instances.partition do |lw|
      uri = URI(Webhookdb.api_url + lw.request_path)
      req = Net::HTTP::Post.new(uri.path, {"Content-Type" => "application/json"})
      req.body = lw.request_body
      # This is going to have these headers:
      # ["content-type", "accept-encoding", "accept", "user-agent", "host"]
      # We want to keep all of these, except if user-agent or content-type were set
      # in the original request; then we want to use those.
      # Additionally, there are a whole set of headers we'll find on our webserver
      # that are added by our web platform, which we do NOT want to include.
      lw.request_headers.each do |k, v|
        next if Webhookdb::LoggedWebhook::WEBHOST_HEADERS.include?(k)
        next if Webhookdb::LoggedWebhook::NONOVERRIDABLE_HEADERS.include?(k)
        req[k] = v
      end
      req[Webhookdb::LoggedWebhook::RETRY_HEADER] = lw.id
      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
      resp.code.to_i < 400
    end
    self.truncate_logs(*successes) if truncate_successful
    return successes, failures
  end

  def retry_one(truncate_successful: false)
    _, bad = self.class.retry_logs([self], truncate_successful:)
    return bad.empty?
  end

  def replay_async
    return self.publish_immediate("replay", self.id)
  end

  # Truncate the logs id'ed by the given instances.
  # Instances are NOT modified; you need to .refresh to see truncated values.
  def self.truncate_logs(*instances)
    ds = self.where(id: instances.map(&:id))
    return self.truncate_dataset(ds)
  end

  def self.truncate_dataset(ds)
    ds = ds.where(truncated_at: nil)
    return ds.update(request_body: "", request_headers: "{}", truncated_at: Time.now)
  end

  def truncated?
    return self.truncated_at ? true : false
  end

  # Insert the logged webhook, and fall back to inserting into the configured
  # available_resilient_database_urls. If none are inserted successfully, raise the error;
  # otherwise, swallow the insert error and more on.
  #
  # Note that these resilient inserts are MUCH slower than normal inserts;
  # they require a separate database connection, CREATE TABLE call, etc.
  # But it's a reasonable way to handle when the database is down.
  def self.resilient_insert(service_integration_opaque_id:, **kwargs)
    Resilient.new.insert(kwargs, {service_integration_opaque_id:})
  end

  # Replay and delete all rows in the resilient database tables.
  def self.resilient_replay
    Resilient.new.replay
  end
end

require "webhookdb/logged_webhook/resilient"

# Table: logged_webhooks
# ---------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                            | bigint                   | PRIMARY KEY DEFAULT nextval('logged_webhooks_id_seq'::regclass)
#  inserted_at                   | timestamp with time zone | NOT NULL DEFAULT now()
#  truncated_at                  | timestamp with time zone |
#  request_body                  | text                     | NOT NULL
#  request_headers               | jsonb                    | NOT NULL
#  response_status               | smallint                 | NOT NULL
#  service_integration_opaque_id | text                     | NOT NULL
#  organization_id               | integer                  |
#  request_method                | text                     | NOT NULL
#  request_path                  | text                     | NOT NULL
# Indexes:
#  logged_webhooks_pkey                                | PRIMARY KEY btree (id)
#  logged_webhooks_inserted_at_index                   | btree (inserted_at)
#  logged_webhooks_organization_id_index               | btree (organization_id)
#  logged_webhooks_service_integration_opaque_id_index | btree (service_integration_opaque_id)
# Foreign key constraints:
#  logged_webhooks_organization_id_fkey | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
# ---------------------------------------------------------------------------------------------------------------------------
