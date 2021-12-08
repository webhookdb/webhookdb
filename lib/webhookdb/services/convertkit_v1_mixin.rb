# frozen_string_literal: true

module Webhookdb::Services::ConvertkitV1Mixin
  def _mixin_name_plural
    raise NotImplementedError
  end

  def _webhook_verified?(_request)
    # Webhook Authentication isn't supported
    return true
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:convertkit_id, "bigint")
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    if self.service_integration.backfill_secret.blank?
      step.output = %(Great! We've created your ConvertKit #{self._mixin_name_plural} integration.

ConvertKit #{self._mixin_name_singular} webhooks are not designed to mirror data, so to fill your database,
we need to use the API to make requests, which requires your API Secret.
#{Webhookdb::Convertkit::FIND_API_SECRET_HELP}
      )
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end
    result = self.verify_backfill_credentials
    unless result.fetch(:verified)
      self.service_integration.service_instance.clear_backfill_information
      step.output = result.fetch(:message)
      return step.secret_prompt("API Secret").backfill_secret(self.service_integration)
    end
    step.output = %(We'll start backfilling your ConvertKit #{self._mixin_name_plural} now,
and they will show up in your database momentarily.
#{self._query_help_output}
    )
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Secret is invalid. Please reenter the API Secret:"
  end

  def _verify_backfill_err_msg
    return "An error occurred. Please reenter the API Secret:"
  end
end
