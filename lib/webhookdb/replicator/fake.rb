# frozen_string_literal: true

class Webhookdb::Replicator::Fake < Webhookdb::Replicator::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :upsert_has_deps
  singleton_attr_accessor :resource_and_event_hook
  singleton_attr_accessor :dispatch_request_to_hook
  singleton_attr_accessor :process_webhooks_synchronously
  singleton_attr_accessor :obfuscate_headers_for_logging
  singleton_attr_accessor :requires_sequence

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_v1",
      ctor: ->(sint) { Webhookdb::Replicator::Fake.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake",
      supports_webhooks: true,
      supports_backfill: true,
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
    self.descendants&.each do |d|
      d.reset if d.respond_to?(:reset)
    end
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
    return super unless self.process_webhooks_synchronously?
    return self.class.process_webhooks_synchronously
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
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
    step = Webhookdb::Replicator::StateMachineStep.new
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
    return Webhookdb::Replicator::Column.new(:my_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(
        :at,
        TIMESTAMP,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
    ]
  end

  def _timestamp_column_name
    return :at
  end

  def _resource_and_event(request)
    return self.class.resource_and_event_hook.call(request) if self.class.resource_and_event_hook
    return request.body, nil
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
    r = Webhookdb::Http.get("https://fake-integration?token=#{pagination_token}", logger: nil, timeout: 30)
    raise "Expected 2-item array" unless r.parsed_response.is_a?(Array) && r.parsed_response.length == 2
    return r.parsed_response
  end

  def upsert_has_deps?
    return self.class.upsert_has_deps
  end
end

class Webhookdb::Replicator::FakeWithEnrichments < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_with_enrichments_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeWithEnrichments.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Enriched Fake",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def _denormalized_columns
    return super << Webhookdb::Replicator::Column.new(:extra, TEXT, from_enrichment: true)
  end

  def _store_enrichment_body?
    return true
  end

  def _fetch_enrichment(resource, _event, _request)
    r = Webhookdb::Http.get("https://fake-integration/enrichment/" + resource["my_id"], logger: nil, timeout: 30)
    return r.parsed_response
  end
end

class Webhookdb::Replicator::FakeDependent < Webhookdb::Replicator::Fake
  singleton_attr_accessor :on_dependency_webhook_upsert_callback

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_dependent_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeDependent.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeDependent",
      dependency_descriptor: Webhookdb::Replicator::Fake.descriptor,
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def on_dependency_webhook_upsert(replicator, payload, changed:)
    self.class.on_dependency_webhook_upsert_callback&.call(replicator, payload, changed:)
  end

  def calculate_webhook_state_machine
    dependency_help = "This is where you would explain things like the relationship between stripe cards and customers."
    if (step = self.calculate_dependency_state_machine_step(dependency_help:))
      return step
    end
    return super
  end
end

class Webhookdb::Replicator::FakeDependentDependent < Webhookdb::Replicator::Fake
  singleton_attr_accessor :on_dependency_webhook_upsert_callback

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_dependent_dependent_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeDependentDependent.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeDependentDependent",
      dependency_descriptor: Webhookdb::Replicator::FakeDependent.descriptor,
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def on_dependency_webhook_upsert(replicator, payload, changed:)
    self.class.on_dependency_webhook_upsert_callback&.call(replicator, payload, changed:)
  end

  def calculate_webhook_state_machine
    dependency_help = "This is where you would explain things like the relationship between stripe cards and customers."
    if (step = self.calculate_dependency_state_machine_step(dependency_help:))
      return step
    end
    return super
  end
end

class Webhookdb::Replicator::FakeEnqueueBackfillOnCreate < Webhookdb::Replicator::Fake
  singleton_attr_accessor :on_dependency_webhook_upsert_callback

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_enqueue_backfill_on_create_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeEnqueueBackfillOnCreate.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeEnqueueBackfillOnCreate",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def calculate_backfill_state_machine
    # To mimic situations where it is possible to enqueue a backfill job on create, this backfill machine does
    # not require any extra information--its initial step is "complete." The main situation where this would
    # happen is if a replicator gets backfill creds from a dependency.
    step = Webhookdb::Replicator::StateMachineStep.new
    step.needs_input = false
    step.output = "The backfill flow is working correctly."
    step.complete = true
    return step
  end
end

class Webhookdb::Replicator::FakeWebhooksOnly < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_webhooks_only_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeWebhooksOnly.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake Webhooks Only (No Backfill)",
      supports_webhooks: true,
      supports_backfill: false,
    )
  end

  def documentation_url = "https://abc.xyz"

  def calculate_backfill_state_machine = raise NotImplementedError
end

class Webhookdb::Replicator::FakeBackfillOnly < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_backfill_only_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeBackfillOnly.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake Backfill Only (No Webhooks)",
      supports_webhooks: false,
      supports_backfill: true,
    )
  end

  def calculate_webhook_state_machine = raise NotImplementedError
end

class Webhookdb::Replicator::FakeBackfillWithCriteria < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_backfill_with_criteria_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeBackfillWithCriteria.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake Backfill with Criteria",
      dependency_descriptor: Webhookdb::Replicator::Fake,
      supports_backfill: true,
    )
  end

  def _denormalized_columns
    return super << Webhookdb::Replicator::Column.new(:backfill_kwargs, OBJECT, optional: true)
  end

  def _backfillers(**kwargs)
    return [CriteriaStoringBackfiller.new(self, kwargs)]
  end

  class CriteriaStoringBackfiller < Webhookdb::Backfiller
    def initialize(svc, kw)
      @svc = svc
      @kw = kw
      super()
    end

    def handle_item(body)
      body["backfill_kwargs"] = @kw
      @svc.upsert_webhook_body(body)
    end

    def fetch_backfill_page(_pagination_token, **_kwargs)
      return [[{"my_id" => "x", "at" => "2022-01-01T00:00:00Z"}], nil]
    end
  end
end

class Webhookdb::Replicator::FakeExhaustiveConverter < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_exhaustive_converter_v1",
      ctor: ->(sint) { Webhookdb::Replicator::FakeExhaustiveConverter.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "Fake with all converters",
      supports_webhooks: true,
      supports_backfill: false,
    )
  end

  def requires_sequence? = true

  # True to return only the superclass columns. Used to test column updates.
  attr_accessor :super_cols_only
  # True to return only the columns that can be used for updates. Used to test column updates.
  # Should be true when testing Ruby converters.
  attr_accessor :exclude_unimplemented_sql_update_cols

  def _denormalized_columns
    cols = super
    return cols if self.super_cols_only
    cols += [
      Webhookdb::Replicator::Column.new(
        :comma_sep,
        TEXT_ARRAY,
        converter: Webhookdb::Replicator::Column::CONV_COMMA_SEP,
      ),
      Webhookdb::Replicator::Column.new(
        :geo_lat,
        DECIMAL,
        data_key: "latlng",
        converter: Webhookdb::Replicator::Column.converter_array_element(index: 0, sep: " ", cls: DECIMAL),
      ),
      Webhookdb::Replicator::Column.new(
        :geo_lng,
        DECIMAL,
        data_key: "latlng",
        converter: Webhookdb::Replicator::Column.converter_array_element(index: 1, sep: " ", cls: DECIMAL),
      ),
      Webhookdb::Replicator::Column.new(:date, DATE, converter: :date),
      Webhookdb::Replicator::Column.new(:datetime, TIMESTAMP, converter: :time),
      Webhookdb::Replicator::Column.new(:parsed_int, INTEGER, converter: :to_i),
      Webhookdb::Replicator::Column.new(:unix_ts, TIMESTAMP, converter: :tsat),
      Webhookdb::Replicator::Column.new(
        :strptime,
        TIMESTAMP,
        converter: Webhookdb::Replicator::Column.converter_strptime("%d%m%Y %H%M%S%Z", "DDMMYYYY HH24MISS", cls: Time),
      ),
      Webhookdb::Replicator::Column.new(
        :strptime_date,
        DATE,
        converter: Webhookdb::Replicator::Column.converter_strptime("%d%Y%m", "DDYYYYMM", cls: Date),
      ),
      Webhookdb::Replicator::Column.new(
        :int_array,
        BIGINT_ARRAY,
        data_key: "obj_array",
        converter: Webhookdb::Replicator::Column.converter_array_pluck("id", BIGINT),
      ),
      Webhookdb::Replicator::Column.new(
        :text_array,
        TEXT_ARRAY,
        data_key: "obj_array",
        converter: Webhookdb::Replicator::Column.converter_array_pluck("name", TEXT),
      ),
      Webhookdb::Replicator::Column.new(
        :subtext,
        TEXT,
        converter: Webhookdb::Replicator::Column.converter_gsub("^hello", "goodbye"),
      ),
      Webhookdb::Replicator::Column.new(
        :regex_extract,
        TEXT,
        data_key: "regex_conv",
        converter: Webhookdb::Replicator::Column.converter_from_regex('/resources/(\d+)'),
      ),
      Webhookdb::Replicator::Column.new(
        :regex_conv,
        INTEGER,
        converter: Webhookdb::Replicator::Column.converter_from_regex('/resources/(\d+)', dbtype: INTEGER),
      ),
      Webhookdb::Replicator::Column.new(
        :to_utc_date,
        DATE,
        converter: Webhookdb::Replicator::Column::CONV_TO_UTC_DATE,
      ),
      Webhookdb::Replicator::Column.new(
        :using_backfill_expr,
        TEXT,
        data_key: "my_id",
        backfill_expr: "hi there",
      ),
      Webhookdb::Replicator::Column.new(
        :using_null_backfill_expr,
        TEXT,
        data_key: "my_id",
        backfill_expr: Sequel[nil],
      ),
      Webhookdb::Replicator::Column.new(
        :using_backfill_statement,
        TEXT,
        data_key: "my_id",
        backfill_statement: Sequel.lit(<<~SQL),
          CREATE OR REPLACE FUNCTION pg_temp.fake_backfiller_update_tests(text)
            RETURNS text AS 'SELECT $1 || $1' LANGUAGE sql IMMUTABLE
        SQL
        backfill_expr: Sequel.lit("pg_temp.fake_backfiller_update_tests(my_id)"),
      ),
    ]
    return cols if self.exclude_unimplemented_sql_update_cols
    cols << Webhookdb::Replicator::Column.new(
      :int_or_seq_has,
      INTEGER,
      converter: Webhookdb::Replicator::Column.converter_int_or_sequence_from_regex('/resources/(\d+)'),
    )
    cols << Webhookdb::Replicator::Column.new(
      :int_or_seq_has_not,
      INTEGER,
      converter: Webhookdb::Replicator::Column.converter_int_or_sequence_from_regex('/resources/(\d+)'),
    )
    cols << Webhookdb::Replicator::Column.new(
      :map_lookup,
      TEXT,
      converter: Webhookdb::Replicator::Column.converter_map_lookup(
        array: false,
        map: {"a" => "A", "b" => "B"},
      ),
    )
    cols << Webhookdb::Replicator::Column.new(
      :map_lookup_array,
      TEXT_ARRAY,
      converter: Webhookdb::Replicator::Column.converter_map_lookup(
        array: true,
        map: {"a" => "A", "b" => "B"},
      ),
    )
    return cols
  end
end

class Webhookdb::Replicator::FakeStaleRow < Webhookdb::Replicator::Fake
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_stale_row_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeStaleRow",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:textcol, TEXT),
    ]
  end

  class StaleRowDeleter < Webhookdb::Replicator::BaseStaleRowDeleter
    def stale_at = 5.days
    def lookback_window = 5.days
    def updated_at_column = :at
    def stale_condition = {textcol: "cancelled"}
    def chunk_size = 10
  end

  def stale_row_deleter = StaleRowDeleter.new(self)
end

class Webhookdb::Replicator::FakeWithWatchChannel < Webhookdb::Replicator::Fake
  singleton_attr_accessor :renew_calls

  def self.reset
    self.renew_calls = []
  end

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "fake_with_watch_channel_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: ["internal"],
      resource_name_singular: "FakeWithWatchChannel",
      supports_webhooks: true,
    )
  end

  def renew_watch_channel(row_pk:, expiring_before:)
    self.class.renew_calls << {row_pk:, expiring_before:}
  end
end
