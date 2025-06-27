# frozen_string_literal: true

require "webhookdb/github"
require "webhookdb/messages/error_generic_backfill"

# Mixin for repo-specific resources like issues and pull requests.
module Webhookdb::Replicator::GithubRepoV1Mixin
  API_VERSION = "2022-11-28"

  def self._api_docs_url(tail)
    return "https://docs.github.com/en/rest#{tail}?apiVersion=#{API_VERSION}"
  end

  # @!attribute service_integration
  # @return [Webhookdb::ServiceIntegration]

  def _mixin_backfill_url = raise NotImplementedError("/issues, /pulls, etc")
  def _mixin_webhook_events = raise NotImplementedError("Issues, Pulls, Issue comments, etc")
  # https://docs.github.com/en/webhooks/webhook-events-and-payloads?actionType=demilestoned#issues
  def _mixin_webhook_key = raise NotImplementedError("issue, etc")
  # https://github.com/settings/personal-access-tokens/new
  def _mixin_fine_grained_permission = raise NotImplementedError("Issues", etc)
  # Query params to use in the list call. Should include sorting when available.
  def _mixin_query_params(last_backfilled:) = raise NotImplementedError
  # Some resources, like issues and pull requests, have a 'simple' representation
  # in the list, and a full representation when fetched individually.
  # Return the field that can be used to determine if the full resource needs to be fetched.
  def _mixin_fetch_resource_if_field_missing = nil

  def _fullreponame = self.service_integration.api_url
  def _repoowner = self._fullreponame.split("/").first
  def _reponame = self._fullreponame.split("/").last
  def _valid_repo_name?(s) = %r{^[\w\-.]+/[\w\-.]+$} =~ s

  # Extract the resource from the request.
  # The resource can be a normal resource, or a webhook,
  # with X-GitHub-Hook-ID key as per https://docs.github.com/en/webhooks/webhook-events-and-payloads
  # The headers are the only things that identify a webhook payload consistently.
  #
  # Note that webhooks to a given integration can be for events we do not expect,
  # such as someone sending events we aren't handling (ie, if they don't uncheck Pushes,
  # we may get push events sent to the github_issue_v1 integration),
  # and also for automated events like 'ping'.
  def _resource_and_event(request)
    # Note the canonical casing on the header name. GitHub sends X-GitHub-Hook-ID
    # but it's normalized here.
    is_webhook = (request.headers || {})["x-github-hook-id"]
    return request.body, nil unless is_webhook
    resource = request.body.fetch(self._mixin_webhook_key, nil)
    return nil, nil if resource.nil?
    return resource, request.body
  end

  def _update_where_expr
    ts = self._timestamp_column_name
    return self.qualified_table_sequel_identifier[ts] < Sequel[:excluded][ts]
  end

  def _webhook_response(request)
    hash = request.env["HTTP_X_HUB_SIGNATURE_256"]
    return Webhookdb::WebhookResponse.error("missing sha256") if hash.nil?
    secret = self.service_integration.webhook_secret
    return Webhookdb::WebhookResponse.error("no secret set, run `webhookdb integration setup`", status: 409) if
      secret.nil?
    request_data = Webhookdb::Http.rewind_request_body(request).read
    verified = Webhookdb::Github.verify_webhook(request_data, hash, secret)
    return Webhookdb::WebhookResponse.ok if verified
    return Webhookdb::WebhookResponse.error("invalid sha256")
  end

  def _webhook_state_change_fields = super + ["repo_name"]

  def process_state_change(field, value)
    attr = field == "repo_name" ? "api_url" : field
    return super(field, value, attr:)
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    return step if self._handle_repo_name_state_machine(step, "repo_name")
    if self.service_integration.webhook_secret.blank?
      step.output = %(Now, head to this route to create a webhook:

  https://github.com/#{self.service_integration.api_url}/settings/hooks/new

For 'Payload URL', use this endpoint that is now available:

  #{self._webhook_endpoint}

For 'Content type', choose 'application/json'. Form encoding works but loses some detail in events.

For 'Secret', choose your own secure secret, or use this one: '#{Webhookdb::Id.rand_enc(16)}'

For 'Which events would you like to trigger this webhook',
choose 'Let me select individual events',
uncheck 'Pushes', and select the following:

  #{self._mixin_webhook_events.join("\n  ")}

Make sure 'Active' is checked, and press 'Add webhook'.)
      return step.secret_prompt("Webhook Secret").webhook_secret(self.service_integration)
    end
    step.output = %(Great! WebhookDB is now listening for #{self.resource_name_singular} webhooks.
#{self._query_help_output})
    return step.completed
  end

  # If api_url isn't set, prompt for it (via repo_name or api_url field).
  def _handle_repo_name_state_machine(step, tfield)
    if self.service_integration.api_url.blank?
      step.output = %(You are about to start replicating #{self.resource_name_plural} for a repository into WebhookDB.

First we need the full repository name, like 'webhookdb/webhookdb-cli'.)
      step.set_prompt("Repository name:").transition_field(self.service_integration, tfield)
      return true
    end
    return false if self._valid_repo_name?(self.service_integration.api_url)
    step.output = %(That repository is not valid. Include both the owner and name, like 'webhookdb/webhookdb-cli'.)
    step.set_prompt("Repository name:").transition_field(self.service_integration, tfield)
    return true
  end

  # If we can make an unauthed request and find the repo, it is public.
  def _is_repo_public?
    resp = Webhookdb::Http.post(
      "https://github.com/#{self.service_integration.api_url}",
      method: :head,
      check: false,
      timeout: 5,
      logger: nil,
    )
    return resp.code == 200
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    return step if self._handle_repo_name_state_machine(step, "api_url")
    unless self.service_integration.backfill_secret.present?
      repo_public = self._is_repo_public?
      step.output = %(In order to backfill #{self.resource_name_plural},
WebhookDB requires an access token to authenticate.

You should go to https://github.com/settings/personal-access-tokens/new and create a new Personal Access Token.

For 'Expiration', give a custom date far in the future.

For 'Resource owner', choose the '#{self._repoowner}' organization.
**If it does not appear**, Fine-grained tokens are not enabled.
See instructions below.

For 'Repository access', choose 'Only select repositories', and the '#{self._fullreponame}' repository.

For 'Repository permissions', go to '#{self._mixin_fine_grained_permission}' and choose 'Read-only access'.

If you didn't see the needed owner under 'Resource owner,' it's because fine-grained tokens are not enabled.
Instead, create a new Classic personal access token from https://github.com/settings/tokens/new.
In the 'Note', mention this token is for WebhookDB,
give it an expiration, and under 'Scopes', ensure #{repo_public ? 'repo->public_repo' : 'repo'} is checked,
since #{self._fullreponame} is #{repo_public ? 'public' : 'private'}.

Then click 'Generate token'.)
      return step.secret_prompt("Personal access token").backfill_secret(self.service_integration)
    end

    unless self.verify_backfill_credentials.verified?
      self.service_integration.replicator.clear_backfill_information
      return self.calculate_backfill_state_machine.
          with_output("That access token didn't seem to work. Please look over the instructions and try again.")
    end

    step.output = %(Great! We are going to start backfilling your #{self.resource_name_plural}.
#{self._query_help_output})
    return step.completed
  end

  JSON_CONTENT_TYPE = "application/vnd.github+json"

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    if pagination_token.present?
      url = pagination_token
      query = {}
    else
      url = "https://api.github.com/repos/#{self.service_integration.api_url}#{self._mixin_backfill_url}"
      query = {per_page: 100}
      query.merge!(self._mixin_query_params(last_backfilled:))
    end
    response, data = self._http_get(url, query)
    next_link = nil
    if response.headers.key?("link")
      links = Webhookdb::Github.parse_link_header(response.headers["link"])
      next_link = links[:next] if links.key?(:next)
    end
    return data, next_link
  end

  def _http_get(url, query)
    response = Webhookdb::Http.get(
      url,
      query,
      headers: {
        "Accept" => JSON_CONTENT_TYPE,
        "Authorization" => "Bearer #{self.service_integration.backfill_secret}",
        "X-GitHub-Api-Version" => API_VERSION,
      },
      logger: self.logger,
      timeout: Webhookdb::Github.http_timeout,
    )
    # Handle the GH-specific vnd JSON or general application/json
    parsed = response.parsed_response
    (parsed = Oj.load(parsed)) if response.headers["content-type"] == JSON_CONTENT_TYPE
    return response, parsed
  end

  def _fetch_enrichment(resource, _event, _request)
    # If we're not set up to backfill, we cannot make an API call.
    return nil if self.service_integration.backfill_secret.nil?
    # We should fetch the full resource if the replicator needs it,
    # and the resource does not have the key we require.
    sentinel_key = self._mixin_fetch_resource_if_field_missing
    return nil if sentinel_key.nil? || resource.key?(sentinel_key)
    resource_url = resource.fetch("url")
    begin
      _response, data = self._http_get(resource_url, {})
    rescue Webhookdb::Http::Error => e
      # If the HTTP call fails due to an auth issue (or a deleted item),
      # we should still upsert what we have.
      # Tokens expire or can be revoked, but we don't want the webhook to stop inserting.
      ignore_error = [401, 403, 404].include?(e.response.code)
      return nil if ignore_error
      raise e
    end
    return data
  end

  def on_backfill_error(be)
    e = Webhookdb::Errors.find_cause(be) do |ex|
      next true if ex.is_a?(Webhookdb::Http::Error) && ex.status == 401
    end
    return unless e
    message = Webhookdb::Messages::ErrorGenericBackfill.new(
      self.service_integration,
      response_status: e.status,
      response_body: e.body,
      request_url: e.uri.to_s,
      request_method: e.http_method,
    )
    self.service_integration.organization.alerting.dispatch_alert(message)
    return true
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    # if enrichment is not nil, it's the detailed resource.
    # See _mixin_fetch_resource_if_field_missing
    return super(enrichment || resource, event, request, nil)
  end

  def _resource_to_data(resource, _event, _request, enrichment)
    # if enrichment is not nil, it's the detailed resource.
    # See _mixin_fetch_resource_if_field_missing
    return enrichment || resource
  end
end
