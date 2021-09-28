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
  let(:page1_items) { raise NotImplementedError }
  let(:page2_items) { raise NotImplementedError }
  # We usually assume 2 pages, plus an empty page as the last query.
  # But in some cases we skip that last empty page if we know we're on the last page,
  # or have no pagination at all.
  let(:expected_backfill_call_count) { 3 }

  before(:each) do
    sint.organization.prepare_database_connections
  end

  after(:each) do
    sint.organization.remove_related_database
  end

  it "upsert records for pages of results" do
    svc.create_table
    svc.backfill
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(page1_items.length + page2_items.length)
    end
  end

  it "retries the page fetch" do
    svc.create_table
    expect(svc).to receive(:wait_for_retry_attempt).twice # Mock out the sleep
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    expected_backfill_call_count.times do
      expect(svc).to receive(:_fetch_backfill_page).and_call_original
    end

    svc.backfill
    svc.readonly_dataset do |ds|
      expect(ds.all).to have_length(page1_items.length + page2_items.length)
    end
  end

  it "errors if backfill credentials are not present" do
    svc.service_integration.backfill_key = ""
    svc.service_integration.backfill_secret = ""
    expect { svc.backfill }.to raise_error(Webhookdb::Services::CredentialsMissing)
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

  def assert_is_enriched(row)
    raise NotImplementedError
  end

  def assert_enrichment_after_insert(db)
    raise NotImplementedError
  end

  it "creates enrichment tables on service table create" do
    svc.create_table
    enrichment_tables.each do |tbl|
      expect(svc.readonly_dataset(&:db)).to be_table_exists(tbl.to_sym)
    end
  end

  it "can use enriched data when inserting" do
    svc.create_table
    svc.upsert_webhook(body: body)
    row = svc.readonly_dataset(&:first)
    assert_is_enriched(row)
  end

  it "calls the after insert hook with the enrichment" do
    svc.create_table
    svc.upsert_webhook(body: body)
    assert_enrichment_after_insert(svc.readonly_dataset(&:db))
  end
end
