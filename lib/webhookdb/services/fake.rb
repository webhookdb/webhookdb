# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :upsert_has_deps
  singleton_attr_accessor :resource_and_event_hook
  singleton_attr_accessor :dispatch_request_to_hook
  singleton_attr_accessor :process_webhooks_synchronously
  singleton_attr_accessor :obfuscate_headers_for_logging
  singleton_attr_accessor :requires_sequence

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "fake_v1",
      ctor: ->(sint) { Webhookdb::Services::Fake.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake",
    )
  end

  def self.reset
    self.webhook_response = Webhookdb::WebhookResponse.ok
    self.upsert_has_deps = false
    self.resource_and_event_hook = nil
    self.dispatch_request_to_hook = nil
    self.process_webhooks_synchronously = nil
    self.obfuscate_headers_for_logging = []
    self.requires_sequence = false
  end

  def self.stub_backfill_request(items, status: 200)
    return WebMock::API.stub_request(:get, "https://fake-integration/?token=").
        to_return(status:, body: [items, nil].to_json, headers: {"Content-Type" => "application/json"})
  end

  def process_webhooks_synchronously?
    return self.class.process_webhooks_synchronously ? true : false
  end

  def preprocess_headers_for_logging(headers)
    self.class.obfuscate_headers_for_logging.each { |h| headers[h] = "***" }
  end

  def synchronous_processing_response_body(**)
    super unless self.process_webhooks_synchronously?
    return self.class.process_webhooks_synchronously
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.output = "You're creating a fake_v1 service integration."
      return step.prompting("fake API secret").webhook_secret(self.service_integration)
    end

    step.output = "The integration creation flow is working correctly. Here is " \
                  "the integration's opaque id, which you'll need to enter in a second: " \
                  "#{self.service_integration.opaque_id}"
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = "Now let's test the backfill flow."
      step.prompt = "Paste or type a string here:"
      step.prompt_is_secret = false
      step.post_to_url = self.service_integration.unauthed_webhook_path + "/transition/backfill_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = "The backfill flow is working correctly."
    step.complete = true
    return step
  end

  def _webhook_response(_request)
    r = self.class.webhook_response
    raise r if r.is_a?(Exception)
    return r
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:my_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(
        :at,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Services::Column::CONV_PARSE_TIME,
      ),
    ]
  end

  def _timestamp_column_name
    return :at
  end

  def _resource_and_event(request)
    body = request.body
    return self.class.resource_and_event_hook.call(body) if self.class.resource_and_event_hook
    return body, nil
  end

  def _update_where_expr
    return Sequel[self.qualified_table_sequel_identifier][:at] < Sequel[:excluded][:at]
  end

  def requires_sequence?
    return self.class.requires_sequence
  end

  def dispatch_request_to(request)
    return self.class.dispatch_request_to_hook.call(request) if self.class.dispatch_request_to_hook
    return super
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    r = Webhookdb::Http.get("https://fake-integration?token=#{pagination_token}", logger: nil)
    raise "Expected 2-item array" unless r.parsed_response.is_a?(Array) && r.parsed_response.length == 2
    return r.parsed_response
  end

  def upsert_has_deps?
    return self.class.upsert_has_deps
  end
end

class Webhookdb::Services::FakeWithEnrichments < Webhookdb::Services::Fake
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "fake_with_enrichments_v1",
      ctor: ->(sint) { Webhookdb::Services::FakeWithEnrichments.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Enriched Fake",
    )
  end

  def _denormalized_columns
    return super << Webhookdb::Services::Column.new(:extra, TEXT, from_enrichment: true)
  end

  def _store_enrichment_body?
    return true
  end

  def _fetch_enrichment(resource, _event, _request)
    r = Webhookdb::Http.get("https://fake-integration/enrichment/" + resource["my_id"], logger: nil)
    return r.parsed_response
  end
end

class Webhookdb::Services::FakeDependent < Webhookdb::Services::Fake
  singleton_attr_accessor :on_dependency_webhook_upsert_callback

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "fake_dependent_v1",
      ctor: ->(sint) { Webhookdb::Services::FakeDependent.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeDependent",
      dependency_descriptor: Webhookdb::Services::Fake.descriptor,
    )
  end

  def on_dependency_webhook_upsert(service_instance, payload, changed:)
    self.class.on_dependency_webhook_upsert_callback&.call(service_instance, payload, changed:)
  end

  def calculate_create_state_machine
    dependency_help = "This is where you would explain things like the relationship between stripe cards and customers."
    if (step = self.calculate_dependency_state_machine_step(dependency_help:))
      return step
    end
    return super
  end
end

class Webhookdb::Services::FakeDependentDependent < Webhookdb::Services::Fake
  singleton_attr_accessor :on_dependency_webhook_upsert_callback

  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "fake_dependent_dependent_v1",
      ctor: ->(sint) { Webhookdb::Services::FakeDependentDependent.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeDependentDependent",
      dependency_descriptor: Webhookdb::Services::FakeDependent.descriptor,
    )
  end

  def on_dependency_webhook_upsert(service_instance, payload, changed:)
    self.class.on_dependency_webhook_upsert_callback&.call(service_instance, payload, changed:)
  end

  def calculate_create_state_machine
    dependency_help = "This is where you would explain things like the relationship between stripe cards and customers."
    if (step = self.calculate_dependency_state_machine_step(dependency_help:))
      return step
    end
    return super
  end
end
