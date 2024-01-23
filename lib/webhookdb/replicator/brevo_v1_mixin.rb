# frozen_string_literal: true

require "webhookdb/brevo"

module Webhookdb::Replicator::BrevoV1Mixin
  def _mixin_backfill_url
    # API  Reference: https://developers.brevo.com/reference/getemaileventreport-1
    "#{self.service_integration.api_url}/v3/smtp/statistics/events"
  end

  def _webhook_response(request)
    Webhookdb::Brevo.webhook_response(request)
  end

  def _timestamp_column_name
    :updated_at
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    query = {}
    (query[:cursor] = pagination_token) if pagination_token.present?
    response = Webhookdb::Http.get(
      self._mixin_backfill_url,
      query,
      headers: {"api-key" => self.service_integration.backfill_key},
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
      )
    data = response.parsed_response
    next_page_param = data.dig("response_metadata", "next_cursor")
    [data["data"], next_page_param]
  end
end
