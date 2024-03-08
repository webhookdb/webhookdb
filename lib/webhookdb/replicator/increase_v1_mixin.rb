# frozen_string_literal: true

require "webhookdb/increase"

module Webhookdb::Replicator::IncreaseV1Mixin
  def _webhook_response(request)
    return Webhookdb::Increase.webhook_response(request, self.service_integration.webhook_secret)
  end

  def _resource_and_event(request) = request.body

  def _timestamp_column_name
    # We derive updated_at from the event, or use 'now'
    return :updated_at
  end

  def _update_where_expr
    ts = self._timestamp_column_name
    return self.qualified_table_sequel_identifier[ts] < Sequel[:excluded][ts]
  end

  def on_dependency_webhook_upsert(_replicator, payload, **)
    self.upsert_webhook_body(payload)
  end

  def _mixin_object_type = raise NotImplementedError
  def _mixin_backfill_path = "/#{self._mixin_object_type}s"
  def _mixin_backfill_url = "#{self._app_sint.api_url}#{self._mixin_backfill_path}"

  def _fetch_enrichment(resource, _event, _request)
    # If the resource type isn't what we expect, it must be an event.
    # In that case, we need to fetch the resource from the API,
    # and replace the event body in prepare_for_insert.
    # The updated_at becomes the event's created_at,
    # which should be fine- it's better than setting updated_at to 'now'
    # since that will be confusing as it looks like a resource was recently updated.
    rtype = resource.fetch("type")
    return nil if rtype == self._mixin_object_type
    raise Webhookdb::InvalidPrecondition, "unexpected resource: #{resource}" unless
      rtype == "event" && resource.fetch("associated_object_type") == self._mixin_object_type
    event_created_at = resource.fetch("created_at")
    response = Webhookdb::Http.get(
      self._mixin_backfill_url + "/#{resource.fetch('associated_object_id')}",
      {},
      headers: self._auth_headers,
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    resource.replace(response.parsed_response)
    resource["updated_at"] = event_created_at
    return nil
  end

  def _app_sint = Webhookdb::Replicator.find_at_root!(self.service_integration, service_name: "increase_app_v1")

  def _auth_headers
    return {"Authorization" => ("Bearer " + self._app_sint.backfill_key)}
  end

  #   def calculate_webhook_state_machine
  #     step = Webhookdb::Replicator::StateMachineStep.new
  #     # if the service integration doesn't exist, create it with some standard values
  #     unless self.service_integration.webhook_secret.present?
  #       step.output = %(You are about to start replicating #{self.resource_name_plural} info into WebhookDB.
  # We've made an endpoint available for #{self.resource_name_singular} webhooks:
  #
  # #{self._webhook_endpoint}
  #
  # From your Increase admin dashboard, go to Applications -> Create Webhook.
  # In the "Webhook endpoint URL" field you can enter the URL above.
  # For the shared secret, you'll have to generate a strong password
  # (you can use '#{Webhookdb::Id.rand_enc(16)}')
  # and then enter it into the textbox.
  #
  # Copy that shared secret value.
  #       )
  #       return step.secret_prompt("secret").webhook_secret(self.service_integration)
  #     end
  #
  #     step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.
  # #{self._query_help_output}
  # In order to backfill existing #{self.resource_name_plural}, run this from a shell:
  #
  #   #{self._backfill_command}
  #     )
  #     return step.completed
  #   end
  #
  def calculate_backfill_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.needs_input = false
    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._query_help_output})
    step.complete = true
    return step
  end
  #
  #   def _verify_backfill_401_err_msg
  #     return "It looks like that API Key is invalid. Please reenter the API Key you just created:"
  #   end
  #
  #   def _verify_backfill_err_msg
  #     return "An error occurred. Please reenter the API Key you just created:"
  #   end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    query = {}
    (query[:cursor] = pagination_token) if pagination_token.present?
    fetched_at = Time.now
    response = Webhookdb::Http.get(
      self._mixin_backfill_url,
      query,
      headers: self._auth_headers,
      logger: self.logger,
      timeout: Webhookdb::Increase.http_timeout,
    )
    data = response.parsed_response
    next_page_param = data.dig("response_metadata", "next_cursor")
    rows = data["data"]
    # In general, we want to use webhooks/events to keep rows updated.
    # But if we are backfilling, touch the 'updated at' timestamp to make sure
    # these rows get inserted.
    # It does mess up history, but we can't get that history to be accurate
    # in the case of a backfill anyway.
    rows.each { |r| r["updated_at"] = fetched_at }
    return rows, next_page_param
  end
end
