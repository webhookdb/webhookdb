# frozen_string_literal: true

module Webhookdb::Replicator::MicrosoftCalendarV1Mixin
  def _resource_and_event(request)
    return request.body, nil
  end

  def _calculate_dependent_replicator_create_state_machine
    # TODO: Revisit this copy
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! You are all set.
Refer to https://webhookdb.com/docs/google-calendar for detailed instructions
on syncing data for your linked Google accounts.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}")})
    return step.completed
  end

  def calculate_backfill_state_machine
    # TODO: Revisit this copy
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(#{self.resource_name_singular} does not support backfilling.
See https://webhookdb.com/docs/google-calendar for instructions on setting up your integration.
You can send WebhookDB the 'REFRESH' and 'RESYNC' messages to refresh a user's access token,
and resync all their Google Calendar data, respectively.

Run `webhookdb integrations reset` if you need to modify the secret for this integration.

#{self._query_help_output(prefix: "You can query available #{self.resource_name_plural}")})
    return step.completed
  end

  def on_dependency_webhook_upsert(_replicator, _payload, **)
    return
  end

  def _webhook_response(request)
    return Webhookdb::WebhookResponse.for_standard_secret(request, self.service_integration.webhook_secret)
  end

  class PaginatedBackfiller < Webhookdb::Backfiller
    def first_page_url_and_params = raise NotImplementedError

    def handle_item(body) = raise NotImplementedError

    def this_svc = raise NotImplementedError

    def fetch_backfill_page(pagination_token, **)
      headers = {"Authorization" => "Bearer #{@access_token}"}

      url, query = pagination_token.blank? ? self.first_page_url_and_params : [pagination_token, {}]

      response = Webhookdb::Http.get(
        url,
        query,
        headers:,
        logger: self.this_svc.logger,
      )
      data = response.parsed_response.fetch("value")
      # the next page link is a full url that includes the page size param (`$top`) as well as the
      # pagination param (`$skip`)
      next_page_link = response.parsed_response.fetch("@odata.nextLink", nil)

      return data, next_page_link
    end
    end
end
