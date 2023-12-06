# frozen_string_literal: true

module Webhookdb::Replicator::IntercomV1Mixin
  # @return [Webhookdb::ServiceIntegration]

  # Quick note on these Intercom integrations: although we will technically be bringing in information from webhooks,
  # all webhooks for the WebhookDB app will use a single endpoint and we use the WebhookDB app's Client Secret for
  # webhook verification, which means that webhooks actually don't require any setup on the integration level. Thus,
  # `supports_webhooks` is false.
  def find_auth_integration
    # rubocop:disable Naming/MemoizedInstanceVariableName
    return @auth ||= Webhookdb::Replicator.find_at_root!(self.service_integration,
                                                         service_name: "intercom_marketplace_root_v1",)
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  def intercom_auth_headers
    root_sint = self.find_auth_integration
    return Webhookdb::Intercom.auth_headers(root_sint.backfill_key)
  end

  def auth_credentials?
    auth = self.find_auth_integration
    return auth.backfill_key.present?
  end

  def _resource_and_event(request)
    body = request.body
    return body.fetch("data").fetch("item"), body if body.fetch("type") == "notification_event"
    return body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _timestamp_column_name
    return :updated_at
  end

  def _webhook_response(request)
    # info for debugging
    intercom_auth = request.env["HTTP_X_HUB_SIGNATURE"]

    return Webhookdb::WebhookResponse.error("missing hmac") if intercom_auth.nil?
    request.body.rewind
    request_data = request.body.read
    verified = Webhookdb::Intercom.verify_webhook(request_data, intercom_auth)
    return Webhookdb::WebhookResponse.ok if verified
    return Webhookdb::WebhookResponse.error("invalid hmac")
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    # can inherit credentials from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(We will start replicating #{self.resource_name_singular} information into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def on_dependency_webhook_upsert(_replicator, _payload, *)
    return
  end

  def _mixin_backfill_url
    raise NotImplementedError
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    unless self.auth_credentials?
      raise Webhookdb::Replicator::CredentialsMissing,
            "This integration requires that the Intercom Auth integration has a valid Auth Token"
    end

    query = {per_page: Webhookdb::Intercom.page_size}
    # Intercom started 500ing with this set to empty.
    query[:starting_after] = pagination_token if pagination_token
    begin
      response = Webhookdb::Http.get(
        self._mixin_backfill_url,
        query:,
        headers: self.intercom_auth_headers,
        logger: self.logger,
        timeout: Webhookdb::Intercom.http_timeout,
      )
    rescue Webhookdb::Http::Error => e
      #  We are looking to catch the "api plan restricted" error. This is always a 403 and every
      # 403 will be an "api plan restricted" error according to the API documentation. Because we
      # specify the API version in our headers we can expect that this won't change.
      raise e unless e.status == 403
      self.logger.warn("intercom_api_restricted", intercom_error: e.body)
      # We should basically noop here, i.e. pretend that the page is empty, so that we don't trigger
      # a TypeError in the backfiller.
      return [], nil
    end
    data = response.parsed_response.fetch("data", [])
    starting_after = response.parsed_response.dig("pages", "next", "starting_after")
    return data, starting_after
  end
end
