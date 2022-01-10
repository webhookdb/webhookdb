# frozen_string_literal: true

RSpec.shared_examples "a service implementation" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_data) { body }

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "can create its table in its org db" do
    svc.create_table
    svc.readonly_dataset do |ds|
      expect(ds.db).to be_table_exists(svc.table_sym)
    end
    expect(sint.db).to_not be_table_exists(svc.table_sym)
  end

  it "can insert into its table" do
    svc.create_table
    svc.upsert_webhook(body:)
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_data)
    end
  end

  it "handles webhooks" do
    request = fake_request
    status, headers, body = svc.webhook_response(request)
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

  it "won't insert webhook of incorrect type" do
    svc.create_table
    svc.upsert_webhook(body: incorrect_webhook)
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
      svc.upsert_webhook(body: old_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_old_data)

      svc.upsert_webhook(body: new_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)
    end
  end

  it "will not override newer rows with older ones" do
    svc.create_table

    svc.readonly_dataset do |ds|
      svc.upsert_webhook(body: new_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)

      svc.upsert_webhook(body: old_body)
      expect(ds.all).to have_length(1)
      expect(ds.first[:data]).to eq(expected_new_data)
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
    expect(result).to include(verified: true, message: "")
  end

  it "if backfill info is incorrect for some other reason, return the a negative result and error message" do
    res = stub_service_request_error
    svc = Webhookdb::Services.service_instance(incorrect_creds_sint)
    result = svc.verify_backfill_credentials
    expect(res).to have_been_made
    expect(result).to include(verified: false, message: be_a(String).and(be_present))
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
  let(:sint) do
    Webhookdb::Fixtures.service_integration.create(
      service_name: name,
      backfill_key: "bfkey",
      backfill_secret: "bfsek",
      api_url: "https://fake-url.com",
    )
  end
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:expected_items_count) { raise NotImplementedError, "how many items do we insert?" }

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
    responses = stub_service_requests
    svc.backfill
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
  end

  it "retries the page fetch" do
    svc.create_table
    expect(svc).to receive(:wait_for_retry_attempt).twice # Mock out the sleep
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    responses = stub_service_requests
    expect(svc).to receive(:_fetch_backfill_page).at_least(:once).and_call_original

    svc.backfill
    expect(responses).to all(have_been_made)
    svc.readonly_dataset { |ds| expect(ds.all).to have_length(expected_items_count) }
  end

  it "errors if backfill credentials are not present" do
    svc.service_integration.backfill_key = ""
    svc.service_integration.backfill_secret = ""
    expect { svc.backfill }.to raise_error(Webhookdb::Services::CredentialsMissing)
  end

  it "errors if fetching page errors" do
    expect(svc).to receive(:wait_for_retry_attempt).twice # Mock out the sleep
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
  let(:enrichment_tables) { raise NotImplementedError }
  let(:body) { raise NotImplementedError }

  before(:each) do
    sint.organization.prepare_database_connections
    svc.create_table
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  # noinspection RubyUnusedLocalVariable
  def stub_service_request
    raise NotImplementedError, "return the stub_request for an enrichment"
  end

  def stub_service_request_error
    raise NotImplementedError, "return an erroring stub_request for an enrichment"
  end

  def assert_is_enriched(_row)
    raise NotImplementedError, 'something like: expect(row[:data]["enrichment"]).to eq({"extra" => "abc"})'
  end

  def assert_enrichment_after_insert(_db)
    raise NotImplementedError, "something like: expect(db[:fake_v1_enrichments].all).to have_length(1)"
  end

  it "creates enrichment tables on service table create" do
    enrichment_tables.each do |tbl|
      expect(svc.readonly_dataset(&:db)).to be_table_exists(tbl.to_sym)
    end
  end

  it "can use enriched data when inserting" do
    req = stub_service_request
    svc.upsert_webhook(body:)
    expect(req).to have_been_made
    row = svc.readonly_dataset(&:first)
    assert_is_enriched(row)
  end

  it "calls the after insert hook with the enrichment" do
    req = stub_service_request
    svc.upsert_webhook(body:)
    expect(req).to have_been_made
    assert_enrichment_after_insert(svc.readonly_dataset(&:db))
  end

  it "errors if fetching enrichment errors" do
    req = stub_service_request_error
    expect { svc.upsert_webhook(body:) }.to raise_error(Webhookdb::Http::Error)
    expect(req).to have_been_made
  end
end
