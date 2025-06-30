# frozen_string_literal: true

RSpec.describe Webhookdb::Dbutil, :db do
  describe "configuration", reset_configuration: described_class do
    before(:each) do
      ENV["SIDEKIQ_CONCURRENCY"] = "51"
      ENV["RAILS_MAX_THREADS"] = "52"
    end

    describe "max connections" do
      it "uses SIDEKIQ_CONCURRENCY if PROC_MODE is sidekiq" do
        ENV["PROC_MODE"] = "sidekiq"
        described_class.reset_configuration
        expect(described_class.max_connections).to eq(51)
      end

      it "uses RAILS_MAX_THREADS concurrency if PROC_MODE is puma" do
        ENV["PROC_MODE"] = "puma"
        described_class.reset_configuration
        expect(described_class.max_connections).to eq(52)
      end

      it "uses an explicit DBUTIL_MAX_CONNECTIONS if set" do
        ENV["PROC_MODE"] = "puma"
        ENV["DBUTIL_MAX_CONNECTIONS"] = "83"
        described_class.reset_configuration
        expect(described_class.max_connections).to eq(83)
      end

      it "uses a default concurrency otherwise" do
        described_class.reset_configuration
        expect(described_class.max_connections).to eq(4)
      end

      it "adds DBUTIL_ADDITONAL_POOL_SIZE to max connections" do
        described_class.reset_configuration(additional_pool_size: 10)
        expect(described_class.max_connections).to eq(14)

        ENV["PROC_MODE"] = "sidekiq"
        described_class.reset_configuration(additional_pool_size: 10)
        expect(described_class.max_connections).to eq(61)

        ENV["PROC_MODE"] = "puma"
        described_class.reset_configuration(additional_pool_size: 10)
        expect(described_class.max_connections).to eq(62)
      end

      it "errors if max_connections is 0 or negative" do
        ENV["DBUTIL_MAX_CONNECTIONS"] = "0"
        expect do
          described_class.reset_configuration(max_connection: 0)
        end.to raise_error(/max_connections is misconfigured/)
      end
    end
  end
end
