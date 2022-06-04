# frozen_string_literal: true

module Webhookdb::Services::TheranestV1Mixin
  # @return [Webhookdb::Services::TheranestAuthV1]
  def find_auth_integration
    return @auth if @auth
    parent = self.service_integration.depends_on
    10.times do
      break if parent.nil?
      if parent.service_name == "theranest_auth_v1"
        @auth = parent
        return parent
      end
      parent = parent.depends_on
    end
    raise Webhookdb::InvalidPostcondition,
          "Could not find theranest auth integration for #{self.inspect}"
  end

  def theranest_api_url
    return self.find_auth_integration.api_url
  end

  def theranest_auth_headers
    return self.find_auth_integration.get_auth_headers
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(We will start backfilling #{self.resource_name_singular} information into your WebhookDB database.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
  end

  def parse_ymd_date(date)
    return Date.strptime(date, "%Y/%m/%d")
  rescue TypeError, Date::Error
    return nil
  end

  def on_dependency_webhook_upsert(_service_instance, _payload, *)
    return
  end
end
