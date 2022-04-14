# frozen_string_literal: true

require "grape"

require "webhookdb/platform"

module Webhookdb::API::Helpers
  extend Grape::API::Helpers

  class Prompt < Grape::Validations::Validators::Base
    def validate(request)
      param_key = @attrs.first
      if @option.is_a?(String)
        prompt_str = @option
        checker = :present?
      else
        prompt_str, checker = @option
      end
      param_value = request.params[param_key]
      is_provided = !param_value.nil?
      is_provided &&= checker.is_a?(Symbol) ? param_value.send(checker) : checker[param_value]
      return if is_provided
      Webhookdb::API::Helpers.prompt_for_required_param!(request, param_key, prompt_str)
    end
  end

  # Error with a 422 prompting for a missing param.
  # The string @CTRLC in the prompt will be replaced with a platform-specific Ctrl+C command.
  # We need this because the prompt string often does not have the request available.
  def self.prompt_for_required_param!(request, key, prompt)
    prompt = prompt.gsub("@CTRLC", Webhookdb::Platform.shortcut_ctrlc(request.env))
    step = Webhookdb::Services::StateMachineStep.new
    step.post_to_url = request.path
    step.post_params = request.params.to_h
    step.post_params_value_key = key
    step.set_prompt(prompt)
    body = Webhookdb::Service.error_body(
      422,
      "Prompt for required params",
      code: "prompt_required_params",
      more: {state_machine_step: Webhookdb::API::StateMachineEntity.represent(step)},
    )
    throw :error, message: body, status: 422, headers: {}
  end
end
