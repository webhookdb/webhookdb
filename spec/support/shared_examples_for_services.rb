# frozen_string_literal: true

RSpec.shared_examples "a service implementation" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_data) { body }
  let(:supports_row_diff) { true }

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
    svc.upsert_webhook_body(body)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_data)
    end
  end

  it "can insert into a custom table when the org has a replication schema set" do
    svc.service_integration.organization.migrate_replication_schema("xyz")
    svc.create_table
    svc.upsert_webhook_body(body)
    svc.admin_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_data)
      # this is how a fully qualified table is represented (schema->table, table->column)
      expect(ds.opts[:from].first).to have_attributes(table: "xyz", column: svc.service_integration.table_name.to_sym)
    end
    svc.readonly_dataset do |ds|
      # Need to make sure readonly user has schema privs
      expect(ds.all).to have_length(1)
    end
  end

  it "emits the rowupsert event if the row has changed", :async, :do_not_defer_events do
    Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
    svc.create_table
    expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).
      with(include(
             "payload" => match_array([sint.id, hash_including("row", "external_id", "external_id_column")]),
           ))
    svc.upsert_webhook_body(body)
  end

  it "does not emit the rowupsert event if the row has not changed", :async, :do_not_defer_events do
    if supports_row_diff
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).once
      svc.create_table
      svc.upsert_webhook_body(body) # Upsert and make sure the next does not run
      expect do
        svc.upsert_webhook_body(body)
      end.to_not publish("webhookdb.serviceintegration.rowupsert")
    end
  end

  it "does not emit the rowupsert event if there are no subscriptions", :async, :do_not_defer_events do
    # No subscription is created so should not publish
    svc.create_table
    expect do
      svc.upsert_webhook_body(body)
    end.to_not publish("webhookdb.serviceintegration.rowupsert")
  end

  it "can serve a webhook response webhooks" do
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
    svc.clear_create_information
    expect(sint).to have_attributes(webhook_secret: "")
  end

  it "clears backfill information" do
    sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
    svc.clear_backfill_information
    expect(sint).to have_attributes(api_url: "")
    expect(sint).to have_attributes(backfill_key: "")
    expect(sint).to have_attributes(backfill_secret: "")
  end
end

RSpec.shared_examples "a service implementation that upserts webhooks only under specific conditions" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:incorrect_webhook) { raise NotImplementedError }

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "won't insert webhook if resource_and_event returns nil" do
    svc.create_table
    svc.upsert_webhook_body(incorrect_webhook)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(0)
    end
  end
end

RSpec.shared_examples "a service implementation that prevents overwriting new data with old" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:old_body) { raise NotImplementedError }
  let(:new_body) { raise NotImplementedError }
  let(:expected_old_data) { old_body }
  let(:expected_new_data) { new_body }

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "will override older rows with newer ones" do
    svc.create_table
    svc.readonly_dataset do |ds|
      svc.upsert_webhook_body(old_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_old_data)

      svc.upsert_webhook_body(new_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)
    end
  end

  it "will not override newer rows with older ones" do
    svc.create_table

    svc.readonly_dataset do |ds|
      svc.upsert_webhook_body(new_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)

      svc.upsert_webhook_body(old_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)
    end
  end
end

RSpec.shared_examples "a service implementation that deals with resources and wrapped events" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:resource_json) { raise NotImplementedError }
  let(:resource_in_envelope_json) { raise NotImplementedError }

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "puts the raw resource in the data column" do
    svc.create_table
    svc.upsert_webhook_body(resource_json)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(resource_json)
    end
  end

  it "puts the enveloped resource in the data column" do
    svc.create_table
    svc.upsert_webhook_body(resource_in_envelope_json)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(resource_json)
    end
  end
end

RSpec.shared_examples "a service implementation that verifies backfill secrets" do
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
    svc = Webhookdb::Services.service_instance(correct_creds_sint)
    result = svc.verify_backfill_credentials
    expect(res).to have_been_made
    expect(result).to have_attributes(verified: true, message: "")
  end

  it "if backfill info is incorrect for some other reason, return the a negative result and error message" do
    res = stub_service_request_error
    svc = Webhookdb::Services.service_instance(incorrect_creds_sint)
    result = svc.verify_backfill_credentials
    expect(res).to have_been_made
    expect(result).to have_attributes(verified: false, message: be_a(String).and(be_present))
  end

  it "returns a failed backfill message if the credentials aren't verified when building the state machine" do
    res = stub_service_request_error
    svc = Webhookdb::Services.service_instance(incorrect_creds_sint)
    result = svc.calculate_backfill_state_machine
    expect(res).to have_been_made
    expect(result).to have_attributes(needs_input: true, output: include("It looks like "), prompt_is_secret: true)
  end
end

RSpec.shared_examples "a service implementation that can backfill" do |name|
  let(:api_url) { "https://fake-url.com" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url:,
    )
  end
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:backfiller_class) { Webhookdb::Backfiller }
  let(:expected_items_count) { raise NotImplementedError, "how many items do we insert?" }

  def insert_required_data_callback
    # For instances where our custom backfillers use info from rows in the dependency table to make requests.
    # The function should take a service instance of the dependency.
    # Something like: `return ->(dep_svc) { insert_some_info }`
    return ->(_dep_svc) { return }
  end

  def stub_service_requests
    raise NotImplementedError, "return stub_request for service"
  end

  def stub_service_request_error
    raise NotImplementedError, "return error stub request"
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "upsert records for pages of results" do
    svc.create_table
    create_all_dependencies(sint)
    unless sint.depends_on.nil?
      dependency_svc = sint.depends_on.service_instance
      dependency_svc.create_table
      insert_required_data_callback.call(dependency_svc)
    end
    responses = stub_service_requests
    svc.backfill
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
  end

  it "retries the page fetch" do
    svc.create_table
    create_all_dependencies(sint)
    unless sint.depends_on.nil?
      dependency_svc = sint.depends_on.service_instance
      dependency_svc.create_table
      insert_required_data_callback.call(dependency_svc)
    end
    backfillers = svc._backfillers
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
    svc.backfill
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
  end

  it "errors if backfill credentials are not present" do
    svc.service_integration.backfill_key = ""
    svc.service_integration.backfill_secret = ""
    # `depends_on` is nil because we haven't created dependencies in this test
    expect { svc.backfill }.to raise_error(Webhookdb::Services::CredentialsMissing)
  end

  it "errors if fetching page errors" do
    svc.create_table
    create_all_dependencies(sint)
    unless sint.depends_on.nil?
      dependency_svc = sint.depends_on.service_instance
      dependency_svc.create_table
      insert_required_data_callback.call(dependency_svc)
    end
    expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
    response = stub_service_request_error
    expect { svc.backfill }.to raise_error(Webhookdb::Http::Error)
    expect(response).to have_been_made.at_least_once
  end
end

RSpec.shared_examples "a service implementation that can backfill incrementally" do |name|
  let(:last_backfilled) { raise NotImplementedError, "what should the last_backfilled_at value be?" }
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url: "https://fake-url.com",
      last_backfilled_at: last_backfilled,
    )
  end
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:expected_new_items_count) { raise NotImplementedError, "how many newer items do we insert?" }
  let(:expected_old_items_count) { raise NotImplementedError, "how many older items do we insert?" }

  def stub_service_requests_new_records
    raise NotImplementedError, "return stub_requests that return newer records for service"
  end

  def stub_service_requests_old_records
    raise NotImplementedError, "return stub_requests that return older records for service"
  end

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "upserts records created since last backfill" do
    svc.create_table
    newer_responses = stub_service_requests_new_records
    older_responses = stub_service_requests_old_records
    svc.backfill(incremental: true)
    expect(newer_responses).to all(have_been_made)
    expect(older_responses).to_not include(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count) }
  end

  it "upserts all records unless incremental is set to true" do
    svc.create_table
    newer_responses = stub_service_requests_new_records
    older_responses = stub_service_requests_old_records
    svc.backfill
    expect(newer_responses).to all(have_been_made)
    expect(older_responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count + expected_old_items_count) }
  end

  it "upserts all records if last_backfilled_at == nil" do
    sint.update(last_backfilled_at: nil)
    svc.create_table
    newer_responses = stub_service_requests_new_records
    older_responses = stub_service_requests_old_records
    svc.backfill
    expect(newer_responses).to all(have_been_made)
    expect(older_responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_new_items_count + expected_old_items_count) }
  end
end

RSpec.shared_examples "a service implementation that uses enrichments" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_enrichment_data) { raise NotImplementedError }

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

  it "adds enrichment column to main table" do
    req = stub_service_request
    svc.upsert_webhook_body(body)
    expect(req).to have_been_made unless req.nil?
    row = svc.readonly_dataset(&:first)
    expect(row[:enrichment]).to eq(expected_enrichment_data)
  end

  it "can use enriched data when inserting" do
    req = stub_service_request
    svc.upsert_webhook_body(body)
    expect(req).to have_been_made unless req.nil?
    row = svc.readonly_dataset(&:first)
    assert_is_enriched(row)
  end

  it "errors if fetching enrichment errors" do
    req = stub_service_request_error
    unless req.nil?
      expect { svc.upsert_webhook_body(body) }.to raise_error(Webhookdb::Http::Error)
      expect(req).to have_been_made
    end
  end
end

RSpec.shared_examples "a service implementation with dependents" do |service_name, dependent_service_name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name:) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_insert) { raise NotImplementedError }
  let(:can_track_row_changes) { true }
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
      dep_svc = dep.service_instance
      expect(dep).to receive(:service_instance).at_least(:once).and_return(dep_svc)
      expect(dep_svc).to receive(:on_dependency_webhook_upsert).twice do |inst, payload, changed:|
        calls << 0
        expect(inst).to eq(svc)
        expect(payload).to eq(expected_insert)
        if can_track_row_changes
          expect(changed).to(calls.length == 1 ? be_truthy : be_falsey)
        else
          expect(changed).to be_truthy
        end
      end
    end
    svc.upsert_webhook_body(body)
    expect(calls).to have_length(1)
    svc.upsert_webhook_body(body)
    expect(calls).to have_length(2)
  end
end

RSpec.shared_examples "a service implementation dependent on another" do |service_name, dependency_service_name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name:) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }

  it "can list and describe the services used as dependencies" do
    this_descriptor = Webhookdb::Services.registered_service!(service_name)
    dep_descriptor = Webhookdb::Services.registered_service!(dependency_service_name)
    expect(this_descriptor.dependency_descriptor).to eq(dep_descriptor)
    expect(sint.dependency_candidates).to be_empty
    Webhookdb::Fixtures.service_integration(service_name: dependency_service_name).create
    expect(sint.dependency_candidates).to be_empty
    dep = create_dependency(sint)
    expect(sint.dependency_candidates).to contain_exactly(be === dep)
  end

  it "errors if there are no dependency candidates" do
    step = sint.service_instance.calculate_create_state_machine
    expect(step).to have_attributes(
      output: match(no_dependencies_message),
    )
  end

  it "asks for the dependency as the first step of its state machine" do
    create_dependency(sint)
    sint.depends_on = nil
    step = sint.service_instance.calculate_create_state_machine
    expect(step).to have_attributes(
      output: match("Enter the number for the"),
    )
  end
end
