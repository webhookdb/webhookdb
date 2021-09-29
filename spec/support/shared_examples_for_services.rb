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
      expect(ds.db.table_exists?(svc.table_sym)).to be_truthy
    end
    expect(sint.db.table_exists?(svc.table_sym)).to be_falsey
  end

  it "can insert into its table" do
    svc.create_table
    svc.upsert_webhook(body: body)
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

RSpec.shared_examples "a service implementation that uses enrichments" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:enrichment_tables) { raise NotImplementedError }
  let(:body) { raise NotImplementedError }

  before(:each) do
    sint.organization.prepare_database_connections
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
    svc.create_table
    enrichment_tables.each do |tbl|
      expect(svc.readonly_dataset(&:db)).to be_table_exists(tbl.to_sym)
    end
  end

  it "can use enriched data when inserting" do
    svc.create_table
    req = stub_service_request
    svc.upsert_webhook(body: body)
    expect(req).to have_been_made
    row = svc.readonly_dataset(&:first)
    assert_is_enriched(row)
  end

  it "calls the after insert hook with the enrichment" do
    svc.create_table
    req = stub_service_request
    svc.upsert_webhook(body: body)
    expect(req).to have_been_made
    assert_enrichment_after_insert(svc.readonly_dataset(&:db))
  end

  it "errors if fetching enrichment errors" do
    req = stub_service_request_error
    expect { svc.upsert_webhook(body: body) }.to raise_error(Webhookdb::Http::Error)
    expect(req).to have_been_made
  end
end
