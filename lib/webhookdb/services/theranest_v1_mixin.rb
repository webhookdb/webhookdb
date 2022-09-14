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

  def theranest_auth_cookie
    return self.find_auth_integration.service_instance.get_cookie
  end

  def theranest_auth_headers
    return self.find_auth_integration.service_instance.get_auth_headers
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _webhook_response(_request)
    # There are no webhooks to respond to, these are backfill-only integrations
    return Webhookdb::WebhookResponse.ok
  end

  # @return [Webhookdb::Services::StateMachineStep]
  def calculate_create_state_machine
    # can inherit the `.ASPXAUTH` piece of the cookie and the API url from the auth dependency
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Services::StateMachineStep.new
    step.output = %(Great! You are all set.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}.")})
    return step.completed
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

  # Converters for use with the denormalized columns
  CONV_PARSE_MDY_SLASH = Webhookdb::Services::Column::IsomorphicProc.new(
    ruby: lambda do |s, **_|
      return Date.strptime(s, "%m/%d/%Y")
    rescue TypeError, Date::Error
      return nil
    end,
    sql: lambda do |e|
      Sequel.case(
        {
          {Sequel.cast(Sequel.function(:pg_typeof, e), :text) => "integer"} => nil,
          {Sequel.cast(e, :text) => %r{\d\d/\d\d/\d\d\d\d}} =>
            Sequel.function(:to_date, Sequel.cast(e, :text), "MM/DD/YYYY"),
        },
        nil,
      )
    end,
  )
  CONV_PARSE_YMD_SLASH = Webhookdb::Services::Column::IsomorphicProc.new(
    ruby: lambda do |s, **_|
      return Date.strptime(s, "%Y/%m/%d")
    rescue TypeError, Date::Error
      return nil
    end,
    sql: lambda do |e|
      Sequel.case(
        {
          {Sequel.cast(Sequel.function(:pg_typeof, e), :text) => "integer"} => nil,
          {Sequel.cast(e, :text) => %r{\d\d\d\d/\d\d/\d\d}} =>
            Sequel.function(:to_date, Sequel.cast(e, :text), "YYYY/MM/DD"),
        },
        nil,
      )
    end,
  )
  CONV_PARSE_DATETIME = Webhookdb::Services::Column::IsomorphicProc.new(
    ruby: lambda do |s, **_|
      return Date.strptime(s, "%m/%d/%Y %H:%M %p")
    rescue TypeError, Date::Error
      return nil
    end,
    sql: lambda do |e|
      Sequel.case(
        {
          {Sequel.cast(Sequel.function(:pg_typeof, e), :text) => "integer"} => nil,
          {Sequel.cast(e, :text) => %r{\d\d/\d\d/\d\d\d\d}} =>
            Sequel.function(:to_date, Sequel.cast(e, :text), "MM/DD/YYYY HH24:MI AM"),
        },
        nil,
      )
    end,
  )
end
