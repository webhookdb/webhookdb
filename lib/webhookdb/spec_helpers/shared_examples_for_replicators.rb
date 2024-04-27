# frozen_string_literal: true

require "webhookdb/spec_helpers/whdb"

# The basics: these shared examples are among the most commonly used.

RSpec.shared_examples "a replicator" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_data) { body }
  let(:supports_row_diff) { true }
  let(:expected_row) { nil }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "knows the expression used to conditionally update" do
    expect(svc._update_where_expr).to be_a(Sequel::SQL::Expression)
  end

  it "has a timestamp column" do
    expect(svc.timestamp_column).to be_a(Webhookdb::DBAdapter::Column)
  end

  it "can create its table in its org db" do
    svc.create_table
    svc.readonly_dataset do |ds|
      expect(ds.db).to be_table_exists(svc.qualified_table_sequel_identifier)
    end
    expect(sint.db).to_not be_table_exists(svc.qualified_table_sequel_identifier)
  end

  it "can insert into its table" do
    svc.create_table
    upsert_webhook(svc, body:)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      if expected_row
        expect(ds.first).to match(expected_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_data)
      end
    end
  end

  it "can insert into a custom table when the org has a replication schema set" do
    svc.service_integration.organization.migrate_replication_schema("xyz")
    svc.create_table
    upsert_webhook(svc, body:)
    svc.admin_dataset do |ds|
      expect(ds.all).to have_length(1)
      if expected_row
        expect(ds.first).to match(expected_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_data)
      end
      # this is how a fully qualified table is represented (schema->table, table->column)
      expect(ds.opts[:from].first).to have_attributes(table: "xyz", column: svc.service_integration.table_name.to_sym)
    end
    svc.readonly_dataset do |ds|
      # Need to make sure readonly user has schema privs
      expect(ds.all).to have_length(1)
    end
  end

  it "emits the rowupsert event if the row has changed", :async, :do_not_defer_events, sidekiq: :fake do
    Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
    svc.create_table
    upsert_webhook(svc, body:)
    expect(Sidekiq).to have_queue.consisting_of(
      job_hash(
        Webhookdb::Jobs::SendWebhook,
        args: contain_exactly(
          hash_including(
            "id",
            "name" => "webhookdb.serviceintegration.rowupsert",
            "payload" => [
              sint.id,
              hash_including("external_id", "external_id_column", "row" => hash_including("data")),
            ],
          ),
        ),
      ),
    )
  end

  it "does not emit the rowupsert event if the row has not changed", :async, :do_not_defer_events, sidekiq: :fake do
    if supports_row_diff
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).once
      svc.create_table
      upsert_webhook(svc, body:) # Upsert and make sure the next does not run
      expect do
        upsert_webhook(svc, body:)
      end.to_not publish("webhookdb.serviceintegration.rowupsert")
      expect(Sidekiq).to have_empty_queues
    end
  end

  it "does not emit the rowupsert event if there are no subscriptions", :async, :do_not_defer_events do
    # No subscription is created so should not publish
    svc.create_table
    expect do
      upsert_webhook(svc, body:)
    end.to_not publish("webhookdb.serviceintegration.rowupsert")
  end

  it "can serve a webhook response" do
    create_all_dependencies(sint)
    request = fake_request
    whresp = svc.webhook_response(request)
    expect(whresp).to be_a(Webhookdb::WebhookResponse)
    status, headers, body = whresp.to_rack
    expect(status).to be_a(Integer)
    expect(headers).to be_a(Hash)
    expect(headers).to include("Content-Type")
    expect(body).to be_a(String)
  end

  it "clears setup information" do
    sint.update(webhook_secret: "wh_sek")
    svc.clear_webhook_information
    expect(sint).to have_attributes(webhook_secret: "")
  end

  it "clears backfill information" do
    sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
    svc.clear_backfill_information
    expect(sint).to have_attributes(api_url: "")
    expect(sint).to have_attributes(backfill_key: "")
    expect(sint).to have_attributes(backfill_secret: "")
  end

  # rubocop:disable Lint/RescueException
  def expect_implemented
    # Same as expect { x }.to_not raise_error(NotImplementedError)
    yield
    # No error is good.
  rescue Exception => e
    # Any other error except NotImplementedError is fine.
    # For example we may error verifying credentials; that's fine.
    raise "method is unimplemented" if e.is_a?(NotImplementedError)
  end
  # rubocop:enable Lint/RescueException

  it "adheres to whether it supports webhooks and backfilling" do
    if svc.descriptor.supports_webhooks_and_backfill?
      expect_implemented { svc.calculate_webhook_state_machine }
      expect_implemented { svc.calculate_backfill_state_machine }
    elsif svc.descriptor.webhooks_only?
      expect_implemented { svc.calculate_webhook_state_machine }
      expect { svc.calculate_backfill_state_machine }.to raise_error(NotImplementedError)
    elsif svc.descriptor.backfill_only?
      expect { svc.calculate_webhook_state_machine }.to raise_error(NotImplementedError)
      expect_implemented { svc.calculate_backfill_state_machine }
    else
      raise TypeError, "invalid ingest behavior"
    end
  end

  it "implements `on_dependency_webhook_upsert` if dependency is present" do
    if svc.descriptor.dependency_descriptor.present?
      expect_implemented do
        svc.on_dependency_webhook_upsert(svc, {}, changed: true)
      end
    end
  end
end

RSpec.shared_examples "a replicator with dependents" do |service_name, dependent_service_name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name:) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_insert) { raise NotImplementedError }
  let(:can_track_row_changes) { true }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "calls on_dependency_webhook_upsert on dependencies with whether the row has changed" do
    svc.create_table
    Webhookdb::Fixtures.service_integration(service_name: dependent_service_name).
      depending_on(svc.service_integration).
      create

    calls = []
    svc.service_integration.dependents.each do |dep|
      dep_svc = dep.replicator
      expect(dep).to receive(:replicator).at_least(:once).and_return(dep_svc)
      expect(dep_svc).to receive(:on_dependency_webhook_upsert).twice do |inst, payload, changed:|
        calls << 0
        expect(inst).to eq(svc)
        expect(payload).to match(expected_insert)
        if can_track_row_changes
          expect(changed).to(calls.length == 1 ? be_truthy : be_falsey)
        else
          expect(changed).to be_truthy
        end
      end
    end
    upsert_webhook(svc, body:)
    expect(calls).to have_length(1)
    upsert_webhook(svc, body:)
    expect(calls).to have_length(2)
  end
end

RSpec.shared_examples "a replicator dependent on another" do |service_name, dependency_service_name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name:) }
  let(:svc) { Webhookdb::Replicator.create(sint) }

  it "can list and describe the replicators used as dependencies" do
    this_descriptor = Webhookdb::Replicator.registered!(service_name)
    dep_descriptor = Webhookdb::Replicator.registered!(dependency_service_name)
    expect(this_descriptor.dependency_descriptor).to eq(dep_descriptor)
    expect(sint.dependency_candidates).to be_empty
    Webhookdb::Fixtures.service_integration(service_name: dependency_service_name).create
    expect(sint.dependency_candidates).to be_empty
    dep = create_dependency(sint)
    expect(sint.dependency_candidates).to contain_exactly(be === dep)
  end

  it "errors if there are no dependency candidates" do
    step = sint.replicator.send(sint.replicator.preferred_create_state_machine_method)
    expect(step).to have_attributes(
      output: match(no_dependencies_message),
    )
  end

  it "asks for the dependency as the first step of its state machine" do
    create_dependency(sint)
    sint.depends_on = nil
    step = sint.replicator.send(sint.replicator.preferred_create_state_machine_method)
    expect(step).to have_attributes(
      output: match("Enter the number for the"),
    )
  end
end

RSpec.shared_examples "a replicator that prevents overwriting new data with old" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:old_body) { raise NotImplementedError }
  let(:new_body) { raise NotImplementedError }
  let(:expected_old_data) { old_body }
  let(:expected_new_data) { new_body }
  let(:expected_old_row) { nil }
  let(:expected_new_row) { nil }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "will override older rows with newer ones" do
    svc.create_table
    svc.readonly_dataset do |ds|
      upsert_webhook(svc, body: old_body)
      expect(ds.all).to have_length(1)
      if expected_old_row
        expect(ds.first).to match(expected_old_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_old_data)
      end

      upsert_webhook(svc, body: new_body)
      expect(ds.all).to have_length(1)
      if expected_new_row
        expect(ds.first).to match(expected_new_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_new_data)
      end
    end
  end

  it "will not override newer rows with older ones" do
    svc.create_table

    svc.readonly_dataset do |ds|
      upsert_webhook(svc, body: new_body)
      expect(ds.all).to have_length(1)
      if expected_new_row
        expect(ds.first).to match(expected_new_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_new_data)
      end

      upsert_webhook(svc, body: old_body)
      expect(ds.all).to have_length(1)
      if expected_new_row
        expect(ds.first).to match(expected_new_row)
      else
        expect(ds.first[:data].to_h).to eq(expected_new_data)
      end
    end
  end
end

RSpec.shared_examples "a replicator that can backfill" do |name|
  let(:api_url) { "https://fake-url.com" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url:,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:backfiller_class) { Webhookdb::Backfiller }
  let(:expected_items_count) { raise NotImplementedError, "how many items do we insert?" }
  let(:has_no_logical_empty_state) { false }

  def insert_required_data_callback
    # For instances where our custom backfillers use info from rows in the dependency table to make requests.
    # The function should take a replicator of the dependency.
    # Something like: `return ->(dep_svc) { insert_some_info }`
    return ->(*) { return }
  end

  def stub_service_requests
    raise NotImplementedError, "return stub_request for service"
  end

  def stub_empty_requests
    raise NotImplementedError, "return stub_request that returns no items (or a response with no key if appropriate)"
  end

  def stub_service_request_error
    raise NotImplementedError, "return error stub request, usually 4xx"
  end

  def reset_backfill_credentials
    svc.service_integration.backfill_key = ""
    svc.service_integration.backfill_secret = ""
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "upsert records for pages of results and updates the backfill job" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_service_requests
    bfjob = backfill(sint)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
    expect(bfjob.refresh).to have_attributes(
      started_at: be_present,
      finished_at: be_present,
    )
  end

  it "handles empty responses" do
    # APIs fall into two sets: those that return consistent shapes no matter the set of data available,
    # and those that remove keys when data is unavailable (there is maybe a third that uses 'nil' instead of '[]'?).
    # When we have APIs in the second group, we need to test them against missing keys;
    # APIs in the first group can reuse structured responses. That is, we do not need every replicator
    # to work against an empty response shape just because we can.
    next if has_no_logical_empty_state
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_empty_requests
    backfill(sint)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to be_empty }
  end

  it "retries the page fetch" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    backfillers = svc._backfillers
    expect(sint).to receive(:replicator).and_return(svc)
    expect(svc).to receive(:_backfillers).and_return(backfillers)
    expect(Webhookdb::Backfiller).to receive(:do_retry_wait).
      exactly(backfillers.size * 2).times # Each backfiller sleeps twice
    # rubocop:disable RSpec/IteratedExpectation
    backfillers.each do |bf|
      expect(bf).to receive(:fetch_backfill_page).and_raise(Webhookdb::Http::BaseError)
      expect(bf).to receive(:fetch_backfill_page).and_raise(Webhookdb::Http::BaseError)
      expect(bf).to receive(:fetch_backfill_page).at_least(:once).and_call_original
    end
    # rubocop:enable RSpec/IteratedExpectation
    responses = stub_service_requests
    backfill(svc)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
  end

  it "errors if backfill credentials are not present" do
    reset_backfill_credentials
    # `depends_on` is nil because we haven't created dependencies in this test
    expect { backfill(sint) }.to raise_error(Webhookdb::Replicator::CredentialsMissing)
  end

  it "errors if fetching page errors" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
    response = stub_service_request_error
    expect { backfill(sint) }.to raise_error(Webhookdb::Http::Error)
    expect(response).to have_been_made.at_least_once
  end
end

# These shared examples test the way a replicator synthesizes and retrieves information from the API.

RSpec.shared_examples "a replicator that may have a minimal body" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:body) { raise NotImplementedError }
  let(:other_bodies) { [] }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "can insert minimal examples into its table" do
    svc.create_table
    all_bodies = [body] + other_bodies
    all_bodies.each { |b| upsert_webhook(svc, body: b) }
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(all_bodies.length)
      expect(ds.first[:data]).to be_present
    end
  end
end

RSpec.shared_examples "a replicator that deals with resources and wrapped events" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:resource_json) { raise NotImplementedError }
  let(:resource_in_envelope_json) { raise NotImplementedError }
  let(:resource_headers) { nil }
  let(:resource_in_envelope_headers) { nil }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "puts the raw resource in the data column" do
    svc.create_table
    upsert_webhook(svc, body: resource_json, headers: resource_headers)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data].to_h).to eq(resource_json)
    end
  end

  it "puts the enveloped resource in the data column" do
    svc.create_table
    upsert_webhook(svc, body: resource_in_envelope_json, headers: resource_in_envelope_headers)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data].to_h).to eq(resource_json)
    end
  end
end

RSpec.shared_examples "a replicator that uses enrichments" do |name, stores_enrichment_column: true|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:body) { raise NotImplementedError }
  # Needed if stores_enrichment_column is true
  let(:expected_enrichment_data) { raise NotImplementedError }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
    svc.create_table
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  # noinspection RubyUnusedLocalVariable
  def stub_service_request
    raise NotImplementedError,
          "return the stub_request for an enrichment if _fetch_enrichment requires HTTP request, else return nil"
  end

  def stub_service_request_error
    raise NotImplementedError,
          "return an erroring stub_request for an enrichment " \
          "if _fetch_enrichment requires HTTP request, else return nil"
  end

  def assert_is_enriched(_row)
    raise NotImplementedError, 'something like: expect(row[:data]["enrichment"]).to eq({"extra" => "abc"})'
  end

  if stores_enrichment_column
    it "adds enrichment column to main table" do
      req = stub_service_request
      upsert_webhook(svc, body:)
      expect(req).to have_been_made unless req.nil?
      row = svc.readonly_dataset(&:first)
      expect(row[:enrichment]).to eq(expected_enrichment_data)
    end
  end

  it "can use enriched data when inserting" do
    req = stub_service_request
    upsert_webhook(svc, body:)
    expect(req).to have_been_made unless req.nil?
    row = svc.readonly_dataset(&:first)
    assert_is_enriched(row)
  end

  it "errors if fetching enrichment errors" do
    req = stub_service_request_error
    unless req.nil?
      expect { upsert_webhook(svc, body:) }.to raise_error(Webhookdb::Http::Error)
      expect(req).to have_been_made
    end
  end
end

RSpec.shared_examples "a replicator that upserts webhooks only under specific conditions" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:incorrect_webhook) { raise NotImplementedError }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "won't insert webhook if resource_and_event returns nil" do
    svc.create_table
    upsert_webhook(svc, body: incorrect_webhook)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(0)
    end
  end
end

# These shared examples can be used to test replicators that support webhooks.

RSpec.shared_examples "a webhook validating replicator that uses credentials from a dependency" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }

  before(:each) do
    create_all_dependencies(sint)
  end

  def make_request_valid(_req) = raise NotImplementedError
  def make_request_invalid(_req) = raise NotImplementedError

  it "returns a validated webhook response the request is valid using credentials from the auth integration" do
    request = fake_request
    make_request_valid(request)
    expect(sint.replicator.webhook_response(request)).to have_attributes(status: be >= 200)
  end

  it "returns an invalid webhook response if the request is is not valid" do
    request = fake_request
    make_request_invalid(request)
    expect(sint.replicator.webhook_response(request)).to have_attributes(status: be_between(400, 499))
  end
end

RSpec.shared_examples "a replicator that processes webhooks synchronously" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:expected_synchronous_response) { raise NotImplementedError }
  Webhookdb::SpecHelpers::Whdb.setup_upsert_webhook_example(self)

  it "is set to process webhooks synchronously" do
    expect(svc).to be_process_webhooks_synchronously
  end

  it "returns expected response from `synchronous_processing_response`" do
    sint.organization.prepare_database_connections
    svc.create_table
    inserting = upsert_webhook(svc)
    synch_resp = svc.synchronous_processing_response_body(upserted: inserting, request: webhook_request)
    expected = expected_synchronous_response
    expect(expected).to be_a(String)
    expect(synch_resp).to eq(expected)
  end
end

# These shared examples test the intricacies of backfill logic.

RSpec.shared_examples "a backfill replicator that requires credentials from a dependency" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:error_message) { raise NotImplementedError }

  before(:each) do
    create_all_dependencies(sint)
  end

  def strip_auth(_sint)
    raise NotImplementedError
  end

  it "raises if credentials are not set" do
    strip_auth(sint)
    expect do
      backfill(sint)
    end.to raise_error(Webhookdb::Replicator::CredentialsMissing).with_message(error_message)
  end
end

RSpec.shared_examples "a replicator that can backfill incrementally" do |name|
  let(:last_backfilled) { raise NotImplementedError, "what should the last_backfilled_at value be to start?" }
  let(:api_url) { "https://fake-url.com" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url:,
      last_backfilled_at: last_backfilled,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:expected_new_items_count) { raise NotImplementedError, "how many newer items do we insert?" }
  let(:expected_old_items_count) { raise NotImplementedError, "how many older items do we insert?" }

  def insert_required_data_callback
    # See backfiller example
    return ->(*) { return }
  end

  def stub_service_requests(partial:)
    msg = if partial
            "return only the stub_requests called in an incremental situation"
          else
            "return all stub_requests for a full backfill"
          end
    raise NotImplementedError, msg
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "upserts records created since last backfill if incremental is true" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_service_requests(partial: true)
    backfill(sint, incremental: true)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count) }
  end

  it "upserts all records if incremental is false" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_service_requests(partial: false)
    backfill(sint, incremental: false)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count + expected_old_items_count) }
  end

  it "upserts all records if last_backfilled_at == nil" do
    sint.update(last_backfilled_at: nil)
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_service_requests(partial: false)
    backfill(sint)
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count + expected_old_items_count) }
  end
end

RSpec.shared_examples "a replicator that alerts on backfill auth errors" do
  let(:name) { described_class.descriptor.name }
  let(:sint_params) { {} }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url: "https://fake-url.com",
      **sint_params,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:template_name) { raise NotImplementedError }

  def stub_service_request
    raise NotImplementedError, "stub the request without setting the return response"
  end

  def handled_responses
    raise NotImplementedError, "Something like: [[:and_return, {status: 401}], [:and_raise, SocketError.new('hi')]]"
  end

  def unhandled_response
    raise NotImplementedError, "Something like: [:and_return, {status: 500}]"
  end

  def insert_required_data_callback
    # See backfiller example
    return ->(*) { return }
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "dispatches an alert and returns true for handled errors" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    Webhookdb::Fixtures.organization_membership.org(sint.organization).verified.admin.create
    req = stub_service_request
    handled_responses.each { |(m, arg)| req.send(m, arg) }
    handled_responses.count.times do
      backfill(sint)
    end
    expect(req).to have_been_made.times(handled_responses.count)
    expect(Webhookdb::Message::Delivery.all).to contain_exactly(
      have_attributes(template: template_name),
    )
  end

  it "does not dispatch an alert, and raises the original error, if unhandled" do
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    Webhookdb::Fixtures.organization_membership.org(sint.organization).verified.admin.create
    req = stub_service_request.send(*unhandled_response)
    expect { backfill(sint) }.to raise_error(Amigo::Retry::OrDie)
    expect(req).to have_been_made
  end
end

RSpec.shared_examples "a replicator that verifies backfill secrets" do
  let(:correct_creds_sint) { raise NotImplementedError, "what sint should we use to test correct creds?" }
  let(:incorrect_creds_sint) { raise NotImplementedError, "what sint should we use to test incorrect creds?" }

  def stub_service_request
    raise NotImplementedError, "return stub_request for service"
  end

  def stub_service_request_error
    raise NotImplementedError, "return 401 error stub request"
  end

  it "returns a positive result if backfill info is correct" do
    res = stub_service_request
    svc = Webhookdb::Replicator.create(correct_creds_sint)
    result = svc.verify_backfill_credentials
    expect(res).to have_been_made
    expect(result).to have_attributes(verified: true, message: "")
  end

  it "if backfill info is incorrect for some other reason, return the a negative result and error message" do
    res = stub_service_request_error
    svc = Webhookdb::Replicator.create(incorrect_creds_sint)
    result = svc.verify_backfill_credentials
    expect(res).to have_been_made
    expect(result).to have_attributes(verified: false, message: be_a(String).and(be_present))
  end

  let(:failed_step_matchers) do
    {output: include("It looks like "), prompt_is_secret: true}
  end

  it "returns a failed backfill message if the credentials aren't verified when building the state machine" do
    res = stub_service_request_error
    svc = Webhookdb::Replicator.create(incorrect_creds_sint)
    result = svc.calculate_backfill_state_machine
    expect(res).to have_been_made
    expect(result).to have_attributes(needs_input: true, **failed_step_matchers)
  end
end

RSpec.shared_examples "a replicator with a custom backfill not supported message" do |name|
  it "has a custom message" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: name)
    expect(sint.replicator.backfill_not_supported_message).to_not include("You may be looking for one of the following")
  end
end

RSpec.shared_examples "a backfill replicator that marks missing rows as deleted" do |name|
  let(:deleted_column_name) { raise NotImplementedError }
  let(:api_url) { "https://fake-url.com" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url:,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:undeleted_count_after_first_backfill) { 2 }
  let(:undeleted_count_after_second_backfill) { 1 }

  def insert_required_data_callback
    # See backfiller example
    return ->(*) { return }
  end

  def stub_service_requests
    raise NotImplementedError, "return all stub_requests for two backfill calls"
  end

  before(:each) do
    sint.organization.prepare_database_connections
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "marks the deleted timestamp column as deleted" do
    responses = stub_service_requests
    backfill(sint)
    first_backfill_items = svc.readonly_dataset { |ds| ds.where(deleted_column_name => nil).all }
    expect(first_backfill_items).to have_length(undeleted_count_after_first_backfill)
    backfill(sint)
    second_backfill_items = svc.readonly_dataset { |ds| ds.where(deleted_column_name => nil).all }
    expect(second_backfill_items).to have_length(undeleted_count_after_second_backfill)
    expect(responses).to all(have_been_made.twice)
  end

  it "does not modify the deleted timestamp column once set" do
    responses = stub_service_requests
    backfill(sint)
    ts = Time.parse("1999-04-20T12:00:00Z")
    svc.admin_dataset { |ds| ds.update(deleted_column_name => ts) }
    backfill(sint)
    expect(responses).to all(have_been_made.twice)
    svc.admin_dataset do |ds|
      expect(ds.all).to all(include(deleted_column_name => match_time(ts)))
    end
  end
end

RSpec.shared_examples "a replicator that ignores HTTP errors during backfill" do |name|
  let(:api_url) { "https://fake-url.com" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url:,
    )
  end
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:backfiller_class) { Webhookdb::Backfiller }

  def insert_required_data_callback
    # For instances where our custom backfillers use info from rows in the dependency table to make requests.
    # The function should take the chain of replicator dependencies.
    # Something like: `return ->(direct_dep_replicator, grandparent_dep_replicator) { insert_some_info }`
    return ->(*) { return }
  end

  def stub_error_requests
    raise NotImplementedError, "return request stubs for all ignored error responses"
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "does not error for any of the configured responses" do
    allow(Webhookdb::Backfiller).to receive(:do_retry_wait).at_least(:once)
    create_all_dependencies(sint)
    setup_dependencies(sint, insert_required_data_callback)
    responses = stub_error_requests
    Array.new(responses.size) { backfill(sint) }
    expect(responses).to all(have_been_made.at_least_times(1))
    svc.readonly_dataset { |ds| expect(ds.all).to be_empty }
  end
end

RSpec.shared_examples "a replicator backfilling against the table of its dependency" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Replicator.create(sint) }
  let(:dep_svc) { @dep_svc }
  let(:external_id_col) { raise NotImplementedError }

  before(:each) do
    sint.organization.prepare_database_connections
    create_all_dependencies(sint)
    @dep_svc = setup_dependencies(sint).first
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  def create_dependency_row(_external_id, _timestamp)
    raise NotImplementedError, "upsert a row"
  end

  it "upserts records created since last backfill if incremental is true" do
    dep_svc.admin_dataset do |ds|
      ds.insert(create_dependency_row("dep1", 1.hours.ago))
      ds.insert(create_dependency_row("dep2", 2.hours.ago))
      ds.insert(create_dependency_row("dep3", 3.hours.ago))
    end
    sint.update(last_backfilled_at: 2.5.hours.ago)
    backfill(sint, incremental: true)
    expect(svc.readonly_dataset(&:all)).to contain_exactly(
      include(external_id_col => "dep1"),
      include(external_id_col => "dep2"),
      # dep3 is too old so wasn't seen
    )
  end

  it "upserts all records if incremental is false" do
    dep_svc.admin_dataset do |ds|
      ds.insert(create_dependency_row("dep1", 1.hours.ago))
      ds.insert(create_dependency_row("dep2", 2.hours.ago))
      ds.insert(create_dependency_row("dep3", 3.hours.ago))
    end
    sint.update(last_backfilled_at: 2.5.hours.ago)
    backfill(sint, incremental: false)
    expect(svc.readonly_dataset(&:all)).to have_length(3)
  end

  it "upserts all records if last_backfilled_at is nil" do
    dep_svc.admin_dataset do |ds|
      ds.insert(create_dependency_row("dep1", 1.hours.ago))
      ds.insert(create_dependency_row("dep2", 2.hours.ago))
      ds.insert(create_dependency_row("dep3", 3.hours.ago))
    end
    sint.update(last_backfilled_at: nil)
    backfill(sint, incremental: true)
    expect(svc.readonly_dataset(&:all)).to have_length(3)
  end
end
