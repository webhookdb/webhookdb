# frozen_string_literal: true

RSpec.describe Webhookdb::Services, :db do
  it "raises for an invalid service" do
    sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
    expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
  end

  shared_examples "a service implementation" do |name|
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:headers) { {} }
    let(:body) { raise NotImplementedError }

    it "can create its table" do
      svc.create_table
      expect(sint.db.table_exists?(svc.table_sym)).to be_truthy
    end

    it "can insert into its table" do
      svc.create_table
      svc.upsert_webhook(headers: headers, body: body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(body)
    end
  end

  shared_examples "a service implementation that prevents overwriting new data with old" do |name|
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: name) }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:old_headers) { {} }
    let(:old_body) { raise NotImplementedError }
    let(:new_headers) { {} }
    let(:new_body) { raise NotImplementedError }

    it "will override older rows with newer ones" do
      svc.create_table
      svc.upsert_webhook(headers: old_headers, body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(old_body)

      svc.upsert_webhook(headers: new_headers, body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
    end

    it "will not override newer rows with older ones" do
      svc.create_table

      svc.upsert_webhook(headers: new_headers, body: new_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)

      svc.upsert_webhook(headers: old_headers, body: old_body)
      expect(svc.dataset.all).to have_length(1)
      expect(svc.dataset.first[:data]).to eq(new_body)
    end
  end

  describe "fake v1" do
    it_behaves_like "a service implementation", "fake_v1" do
      let(:body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "fake_v1" do
      let(:old_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2015 21:12:33 +0000",
        }
      end
      let(:new_body) do
        {
          "my_id" => "abc",
          "at" => "Thu, 30 Jul 2016 21:12:33 +0000",
        }
      end
    end
  end
end
