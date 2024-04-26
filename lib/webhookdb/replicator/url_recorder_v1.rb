# frozen_string_literal: true

class Webhookdb::Replicator::UrlRecorderV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "url_recorder_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: [],
      resource_name_singular: "URL Recorder",
      supports_webhooks: true,
      supports_backfill: false,
      description: "Record any visit to the webhook URL for later inspection. " \
                   "Useful for recording scans, like visiting QR Code. After the webhook, " \
                   "visitors can be redirected, or shown a Markdown page.",
    )
  end

  def _remote_key_column = Webhookdb::Replicator::Column.new(:unique_id, BIGINT)

  def requires_sequence? = true

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    return [
      col.new(:inserted_at, TIMESTAMP, index: true),
      col.new(:request_method, TEXT),
      col.new(:path, TEXT),
      col.new(:full_url, TEXT),
      col.new(:user_agent, TEXT),
      col.new(:ip, TEXT),
      col.new(:content_type, TEXT),
      col.new(:parsed_query, OBJECT),
      col.new(:parsed_body, OBJECT),
      col.new(:raw_body, TEXT),
    ]
  end

  def _timestamp_column_name = :inserted_at
  def _resource_and_event(_request) = [{}, nil]

  def _update_where_expr = self.qualified_table_sequel_identifier[:inserted_at] < Sequel[:excluded][:inserted_at]

  def _prepare_for_insert(_resource, event, request, enrichment)
    # rr = Rack::Request.new
    rr = request.rack_request
    raise Webhookdb::InvalidPrecondition, "#{request} must have rack_request set" if rr.nil?
    r = {
      "unique_id" => self.service_integration.sequence_nextval,
      "inserted_at" => Time.now,
      "request_method" => rr.request_method,
      "path" => rr.path,
      "parsed_query" => rr.GET,
      "raw_query" => rr.query_string,
      "full_url" => rr.url,
      "user_agent" => rr.user_agent,
      "ip" => rr.ip,
      "content_type" => rr.content_type,
      "raw_body" => nil,
      "parsed_body" => nil,
    }
    if !request.body.is_a?(String)
      # If we were able to parse the request body (usually means it's JSON), store it.
      r["parsed_body"] = request.body
    elsif rr.POST.present?
      # If Rack was able to parse the request body (usually means it's form encoded), store it.
      r["parsed_body"] = rr.POST
    else
      # Store the raw body if nothing can parse it.
      r["raw_body"] = request.body
    end
    return super(r, event, request, enrichment)
  end

  def _resource_to_data(*) = {}

  def _webhook_response(_request) = self.redirect? ? self._redirect_response : self._page_response

  def process_webhooks_synchronously? = true

  def synchronous_processing_response_body(*)
    resp = self.redirect? ? self._redirect_response : self._page_response
    return resp.body
  end

  def redirect? = self.service_integration.api_url =~ %r{^https?://}

  def _redirect_response
    headers = {"Location" => self.service_integration.api_url, "Content-Type" => "text/plain"}
    return Webhookdb::WebhookResponse.new(status: 302, headers:, body: "")
  end

  def _page_response
    headers = {"Content-Type" => "text/html; charset=UTF-8"}
    content = self.service_integration.api_url
    content_is_doc = content.start_with?("<!DOCTYPE") || content.starts_with?("<html")
    body = if content_is_doc
             content
    else
      tmpl_file = File.open(Webhookdb::DATA_DIR + "messages/replicators/url-recorder.liquid")
      liquid_tmpl = Liquid::Template.parse(tmpl_file.read)
      liquid_tmpl.render!({"content" => content})
    end
    return Webhookdb::WebhookResponse.new(status: 200, headers:, body:)
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.api_url.blank?
      step.output = %(After users visit the WebhookDB endpoint,
they can either be redirected to a location of your own,
or we'll render an HTML page to show them.

To use a redirect, input a URL starting with 'https://'.

To render a page, paste in the HTML:

- If the text starts with an `html` tag, it will be used as-is
  for the page's HTML, so you can use your own styles.
- Otherwise we assume the content is a relatively simple message,
  and it's rendered with basic WebhookDB styles.)
      return step.prompting("URL, HTML, or text").api_url(self.service_integration)
    end
    step.output = %(
All set! Every visit to
  #{self.webhook_endpoint}
will be recorded.

If you want to modify what users see after the visit is recorded,
run `webhookdb integration reset #{self.descriptor.name}.

#{self._query_help_output})
    return step.completed
  end
end
