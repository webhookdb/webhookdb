# frozen_string_literal: true

class Webhookdb::Services::StateMachineStep
  attr_accessor :needs_input,
                :prompt,
                :prompt_is_secret,
                :post_to_url,
                :complete,
                :output,
                :error_code

  def initialize
    @needs_input = false
    @prompt = false
    @prompt_is_secret = false
    @post_to_url = ""
    @complete = false
    @output = ""
    @error_code = ""
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def completed
    self.complete = true
    self.needs_input = false
    return self
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def secret_prompt(field)
    return self.prompting(field, secret: true)
  end

  def prompting(field, secret: false)
    self.needs_input = true
    self.prompt = "Paste or type your #{field} here:"
    self.prompt_is_secret = secret
    self.complete = false
    return self
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def backfill_secret(sint)
    self.post_to_url = "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret"
    return self
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def backfill_key(sint)
    self.post_to_url = "/v1/service_integrations/#{sint.opaque_id}/transition/backfill_key"
    return self
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def webhook_secret(sint)
    self.post_to_url = "/v1/service_integrations/#{sint.opaque_id}/transition/webhook_secret"
    return self
  end
end
