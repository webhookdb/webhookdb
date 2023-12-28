# frozen_string_literal: true

require "grape"
require "webhookdb/jobs/process_webhook"

module Webhookdb::API::Helpers
  extend Grape::API::Helpers

  # Prompt for input given some criteria.
  #
  # NOTE: You cannot use :prompt with 'requires', or 'allow_blank'.
  # You MUST use 'optional', and not specify allow_blank
  # (validation will error if these conditions are not met).
  # The semantics around prompts are too subtle to use these built-in validators;
  # we must use our own.
  # Note also, while :default will not error (because we cannot detect it easily),
  # it should not be used since it defeats the purpose of :prompt.
  #
  # The main complexity is around optional params
  # that will take a given default if blank (but we need to prompt if not supplied),
  # or 'enter to confirm' type prompts, where we want to prompt if not supplied.
  #
  # To handle these cases, use the :optional and :confirm options, as below.
  # On the Go client, use string pointers for these values, with omitempty;
  # they will still submit an empty string, but will not include the key if nil.
  #
  # Examples:
  #
  #   requires :param, prompt: "Enter a value:"
  #
  # This is by far the most common usage.
  # If :param is not present (ie, `params[:param].present?` is falsy),
  # a 422 is returned with a StateMachineStep with a prompt value of 'Enter a value:'.
  #
  # All other forms use a Hash instead of a string as the argument.
  #
  #   requires :param, prompt: {message: 'Enter secret:', secret: true}
  #
  # Same as above, but the prompt is set to be a secret.
  #
  #   requires :param, prompt: {message: 'Press Enter to confirm, or Ctrl+C to cancel:', confirm: true}
  #
  # This will 422 if :param is not provided or is nil;
  # it will pass otherwise (so empty values, like '' or false, are valid).
  # This is used to guard against actions that need confirmation.
  # Note that in many situations, we don't know about the need to confirm
  # until we're into the body of the endpoint. In these cases,
  # use `Webhookdb::API::Helpers.prompt_for_required_param!` directly,
  # along with something like `optional :param`.
  #
  #   requires :param, prompt: {message: 'This will default', optional: true}
  #
  # This will 422 if not provided, but will pass otherwise
  # (so nil, '', and false are all valid values).
  #
  #   optional :param, prompt: {message: 'Bypassable', disable: ->(req) { req.env['HTTP_NOPROMPT']} }
  #
  # This will disable the prompt behavior if the proc given to :disable returns true.
  # This is mostly useful when we want to avoid prompting for something
  # because the endpoint is going to have some particular behavior that will avoid the purpose of the prompt.
  #
  class Prompt < ::Grape::Validations::Validators::Base
    def validate(request)
      raise "allow_blank must not be set" unless @allow_blank.nil?
      attr_name = @attrs.first
      if @option.is_a?(String)
        options = {message: @option}
      else
        options = @option
        raise "Missing :message key in prompt args" unless options[:message]
      end
      raise "must use optional for #{attr_name}" if @required
      return unless self.needs_prompt?(attr_name, request, options)
      Webhookdb::API::Helpers.prompt_for_required_param!(
        request,
        attr_name,
        options[:message],
        secret: options[:secret] || false,
      )
    end

    protected def needs_prompt?(attr_name, request, options)
      if (disable_proc = options[:disable]) && (disable_proc[request])
        return false
      end
      params = request.params
      if options[:confirm]
        return true unless params.key?(attr_name)
        return true if params[attr_name].nil?
        return false
      end
      if options[:optional]
        return true unless params.key?(attr_name)
        return false
      end
      value = params[attr_name]
      return false if value.present?
      return false if value.is_a?(FalseClass)
      return true
    end
  end

  def self.prompt_for_required_param!(request, key, prompt, secret: false, output: "")
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = output
    step.post_to_url = request.path
    step.post_params = request.params.to_h
    step.post_params_value_key = key
    step.set_prompt(prompt, secret:)
    body = Webhookdb::Service.error_body(
      422,
      "Prompt for required params",
      code: "prompt_required_params",
      more: {state_machine_step: Webhookdb::API::StateMachineEntity.represent(step)},
    )
    throw :error, message: body, status: 422, headers: {"Whdb-Prompt" => key.to_s}
  end

  def lookup_service_integration!(org, identifier)
    sints = org.service_integrations_dataset.
      where(Sequel[service_name: identifier] | Sequel[table_name: identifier] | Sequel[opaque_id: identifier]).
      limit(2).all
    return sints.first if sints.size == 1
    merror!(403, "There is no service integration with that identifier.") if sints.empty?
    dupe_attr = nil
    alternative = nil
    if sints.first.service_name == identifier
      dupe_attr = "service name"
      alternative = "table name"
    else
      dupe_attr = "table name"
      alternative = "service name"
    end
    msg403 = "There are multiple integrations with that #{dupe_attr}. " \
             "Try again using an integration id, or a #{alternative}. " \
             "Use `webhookdb integrations list` to see all integrations."
    merror!(409, msg403)
  end

  # Our primary webhook endpoint is /v1/service_integrations/<opaque_id>,
  # but in some cases we need a 'static' endpoint for apps to send to,
  # like /v1/install/front/webhooks.
  # Those endpoints share the webhook handling behavior with this method.
  def handle_webhook_request(opaque_id, &)
    raise LocalJumpError unless block_given?
    begin
      sint = yield
      request_headers = request.headers.dup
      svc = Webhookdb::Replicator.create(sint).dispatch_request_to(request)
      svc.preprocess_headers_for_logging(request_headers)
      handling_sint = svc.service_integration
      whresp = svc.webhook_response(request)
      s_status, s_headers, s_body = whresp.to_rack
      (s_status = 200) if s_status >= 400 && Webhookdb.regression_mode?

      if s_status >= 400
        logger.warn "rejected_webhook", webhook_headers: request.headers.to_h,
                                        webhook_body: env["api.request.body"]
        header "Whdb-Rejected-Reason", whresp.reason
      else
        process_kwargs = {
          headers: request.headers,
          body: env["api.request.body"] || {},
          request_path: request.path_info,
          request_method: request.request_method,
        }
        event_json = Amigo::Event.create(
          "webhookdb.serviceintegration.webhook", [handling_sint.id, process_kwargs],
        ).as_json
        # Audit Log this synchronously.
        # It should be fast enough. We may as well log here so we can avoid
        # serializing the (large) webhook payload multiple times, as with normal pubsub.
        Webhookdb::Async::AuditLogger.new.perform(event_json)
        if svc.process_webhooks_synchronously? || Webhookdb::Replicator.always_process_synchronously
          whreq = Webhookdb::Replicator::WebhookRequest.new(
            method: process_kwargs[:request_method],
            path: process_kwargs[:request_path],
            headers: process_kwargs[:headers],
            body: process_kwargs[:body],
          )
          inserted = svc.upsert_webhook(whreq)
          s_body = svc.synchronous_processing_response_body(upserted: inserted, request: whreq)
        else
          queue = svc.upsert_has_deps? ? "netout" : "webhook"
          Webhookdb::Jobs::ProcessWebhook.set(queue:).perform_async(event_json)
        end
      end

      s_headers.each { |k, v| header k, v }
      if s_headers["Content-Type"] == "application/json"
        body Oj.load(s_body)
      else
        env["api.format"] = :binary
        body s_body
      end
      status s_status
    ensure
      _log_webhook_request(opaque_id, sint&.organization_id, s_status, request_headers)
    end
  end

  def _log_webhook_request(opaque_id, organization_id, sstatus, request_headers)
    return if request.headers[Webhookdb::LoggedWebhook::RETRY_HEADER]
    # Status can be set from:
    # - the 'status' method, which will be 201 if it hasn't been set,
    # or another value if it has been set.
    # - the webhook responder, which could respond with 401, etc
    # - if there was an exception- so no status is set yet- use 0
    # The main thing to watch out for is that we:
    # - Cannot assume an exception is a 500 (it can be rescued later)
    # - Must handle error! calls
    # Anyway, this is all pretty confusing, but it's all tested.
    rstatus = status == 201 ? (sstatus || 0) : status
    request.body.rewind
    Webhookdb::LoggedWebhook.dataset.insert(
      request_body: request.body.read,
      request_headers: request_headers.to_json,
      request_method: request.request_method,
      request_path: request.path_info,
      response_status: rstatus,
      organization_id:,
      service_integration_opaque_id: opaque_id,
    )
  end
end
