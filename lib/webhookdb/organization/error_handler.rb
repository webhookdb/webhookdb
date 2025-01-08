# frozen_string_literal: true

require "premailer"

class Webhookdb::Organization::ErrorHandler < Webhookdb::Postgres::Model(:organization_error_handlers)
  include Webhookdb::Dbutil

  DOCS_URL = "https://docs.webhookdb.com/docs/integrating/error-handlers.html"

  plugin :timestamps

  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :created_by, class: "Webhookdb::Customer"

  # @param tmpl [Webhookdb::Message::Template]
  def payload_for_template(tmpl)
    params = {
      error_type: tmpl.class.name.split("::").last.underscore,
      details: tmpl.liquid_drops.to_h,
      signature: tmpl.signature,
      organization_key: self.organization.key,
      service_integration_id: tmpl.service_integration.opaque_id,
      service_integration_name: tmpl.service_integration.service_name,
      service_integration_table: tmpl.service_integration.table_name,
    }
    recipient = Webhookdb::Message::Transport.for(:email).recipient(Webhookdb.support_email)
    message = Webhookdb::Message.render(tmpl, :email, recipient)
    message = message.to_s.strip
    message = Premailer.new(
      message,
      with_html_string: true,
      warn_level: Premailer::Warnings::SAFE,
    )
    message = message.to_plain_text
    params[:message] = message
    return params
  end

  def dispatch(payload)
    if self.sentry?
      self._handle_sentry(payload)
      return
    end

    Webhookdb::Http.post(
      self.url,
      payload,
      timeout: Webhookdb::Organization::Alerting.error_handler_timeout,
      logger: self.logger,
    )
  end

  def sentry?
    u = URI(self.url)
    return u.scheme == "sentry" || u.host&.end_with?("sentry.io")
  end

  MAX_SENTRY_TAG_CHARS = 200

  # See https://develop.sentry.dev/sdk/data-model/envelopes/ for directly posting to Sentry.
  # We do NOT want to use the SDK here, since we do not want to leak anything,
  # and anyway, the runtime information is not important.
  def _handle_sentry(payload)
    payload = payload.deep_symbolize_keys
    now = Time.now.utc
    # We can assume the url is the Sentry DSN
    u = URI(self.url)
    key = u.user
    project_id = u.path.delete("/")
    # Give some valid value for this, though it's not accurate.
    client = "sentry-ruby/5.22.1"
    ts = now.to_i
    # Auth headers are done by capturing an actual request. The docs aren't clear about their format.
    # It's possible using the DSN auth would also work but let's use this.
    headers = {
      "Content-Type" => "application/x-sentry-envelope",
      "X-Sentry-Auth" => "Sentry sentry_version=7, sentry_key=#{key}, sentry_client=#{client}, sentry_timestamp=#{ts}",
    }
    event_id = Uuidx.v4
    # The first line will be used as the title.
    message = "WebhookDB Error in #{payload.fetch(:service_integration_name)}\n\n#{payload.fetch(:message)}"
    # Let the caller set the level through query params
    level = URI.decode_www_form(u.query || "").to_h.fetch("level", "warning")

    # Split structured data into 'extra' (cannot be searched on, just shows in the UI)
    # and 'tags' (can be searched/faceted on, shows in the right bar).
    ignore_tags = Webhookdb::Message::Template.new.liquid_drops.keys.to_set
    tags, extra = payload.fetch(:details).partition do |k, v|
      # Non-strings are always tags
      next true unless v.is_a?(String)
      # Never tag on basic stuff that doesn't change ever
      next false if ignore_tags.include?(k)
      # Unstructured strings may include spaces or braces, and are not tags
      next false if v.include?(" ") || v.include?("{")
      # If it's a small string, treat it as a tag.
      v.size < MAX_SENTRY_TAG_CHARS
    end

    # Envelope structure is a multiline JSON file, I guess jsonl format
    envelopes = [
      {event_id:, sent_at: now.iso8601},
      {type: "event", content_type: "application/json"},
      {
        event_id:,
        timestamp: now.iso8601,
        platform: "ruby",
        level:,
        transaction: payload.fetch(:service_integration_table),
        release: "webhookdb@#{Webhookdb::RELEASE}",
        environment: Webhookdb::RACK_ENV,
        tags: tags.to_h,
        extra: extra.to_h,
        # We should use the same grouping for these messages as we would for emails
        fingerprint: [payload.fetch(:signature)],
        message: message,
      },
    ]
    body = envelopes.map(&:to_json).join("\n")
    store_url = URI(self.url)
    store_url.scheme = "https" if store_url.scheme == "sentry"
    store_url.user = nil
    store_url.password = nil
    store_url.path = "/api/#{project_id}/envelope/"
    store_url.query = ""
    Webhookdb::Http.post(
      store_url.to_s,
      body,
      headers:,
      timeout: Webhookdb::Organization::Alerting.error_handler_timeout,
      logger: self.logger,
    )
  end

  #
  # :Sequel Hooks:
  #

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("oeh")
  end
end
