# frozen_string_literal: true

RSpec.shared_examples "a service implementation" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:body) { raise NotImplementedError }
  let(:expected_data) { body }

  it "can create its table" do
    svc.create_table
    expect(sint.db.table_exists?(svc.table_sym)).to be_truthy
  end

  it "can insert into its table" do
    svc.create_table
    svc.upsert_webhook(body: body)
    expect(svc.dataset.all).to have_length(1)
    expect(svc.dataset.first[:data]).to eq(expected_data)
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

RSpec.shared_examples "a service implementation that prevents overwriting new data with old" do |name|
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
  let(:svc) { Webhookdb::Services.service_instance(sint) }
  let(:old_body) { raise NotImplementedError }
  let(:new_body) { raise NotImplementedError }
  let(:expected_old_data) { old_body }
  let(:expected_new_data) { new_body }

  it "will override older rows with newer ones" do
    svc.create_table
    svc.upsert_webhook(body: old_body)
    expect(svc.dataset.all).to have_length(1)
    expect(svc.dataset.first[:data]).to eq(expected_old_data)

    svc.upsert_webhook(body: new_body)
    expect(svc.dataset.all).to have_length(1)
    expect(svc.dataset.first[:data]).to eq(expected_new_data)
  end

  it "will not override newer rows with older ones" do
    svc.create_table

    svc.upsert_webhook(body: new_body)
    expect(svc.dataset.all).to have_length(1)
    expect(svc.dataset.first[:data]).to eq(expected_new_data)

    svc.upsert_webhook(body: old_body)
    expect(svc.dataset.all).to have_length(1)
    expect(svc.dataset.first[:data]).to eq(expected_new_data)
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

  it "upsert records for pages of results" do
    svc.create_table
    svc.backfill
    expect(svc.dataset.all).to have_length(page1_items.length + page2_items.length)
  end

  it "retries the page fetch" do
    svc.create_table
    expect(svc).to receive(:wait_for_retry_attempt).twice # Mock out the sleep
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
    expect(svc).to receive(:_fetch_backfill_page).and_call_original
    expect(svc).to receive(:_fetch_backfill_page).and_call_original
    expect(svc).to receive(:_fetch_backfill_page).and_call_original

    svc.backfill
    expect(svc.dataset.all).to have_length(page1_items.length + page2_items.length)
  end

  it "errors if backfill credentials are not present" do
    svc.service_integration.backfill_key = ""
    svc.service_integration.backfill_secret = ""
    expect { svc.backfill }.to raise_error(Webhookdb::Services::CredentialsMissing)
  end
end
