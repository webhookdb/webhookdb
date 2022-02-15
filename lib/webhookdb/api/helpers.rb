# frozen_string_literal: true

require "grape"

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

  def self.prompt_for_required_param!(request, key, prompt)
    step = Webhookdb::Services::StateMachineStep.new
    step.post_to_url = request.path
    step.post_params = request.params.to_h
    step.post_params_value_key = key
    step.set_prompt(prompt)
    body = Webhookdb::Service.error_body(
      426,
      "Prompt for required params",
      code: "prompt_required_params",
      more: {state_machine_step: Webhookdb::API::StateMachineEntity.represent(step)},
    )
    throw :error, message: body, status: 426, headers: {}
  end
end
