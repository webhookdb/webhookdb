# frozen_string_literal: true

class Webhookdb::Replicator::StateMachineStep
  attr_accessor :needs_input,
                :prompt,
                :prompt_is_secret,
                :post_to_url,
                :complete,
                :output,
                :error_code,
                :post_params,
                :post_params_value_key

  def initialize
    @needs_input = false
    @prompt = ""
    @prompt_is_secret = false
    @post_to_url = ""
    @complete = false
    @output = ""
    @error_code = ""
    @post_params = {}
    @post_params_value_key = "value"
  end

  def successful? = return self.complete && self.error_code.blank?

  # @return [Webhookdb::Replicator::StateMachineStep]
  def completed
    self.complete = true
    self.needs_input = false
    return self
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def secret_prompt(field)
    return self.prompting(field, secret: true)
  end

  def prompting(field, secret: false)
    return self.set_prompt("Paste or type your #{field} here:", secret:)
  end

  def set_prompt(value, secret: false)
    self.needs_input = true
    self.prompt = value
    self.prompt_is_secret = secret
    self.complete = false
    return self
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def backfill_secret(sint) = self.transition_field(sint, "backfill_secret")

  # @return [Webhookdb::Replicator::StateMachineStep]
  def backfill_key(sint) = self.transition_field(sint, "backfill_key")

  # @return [Webhookdb::Replicator::StateMachineStep]
  def webhook_secret(sint) = self.transition_field(sint, "webhook_secret")

  # @return [Webhookdb::Replicator::StateMachineStep]
  def api_url(sint) = self.transition_field(sint, "api_url")

  # @return [Webhookdb::Replicator::StateMachineStep]
  def transition_field(sint, field)
    self.post_to_url = sint.authed_api_path + "/transition/#{field}"
    return self
  end
end
