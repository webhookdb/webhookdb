# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator, :db do
  describe "looking up a replicator" do
    it "raises for an invalid replicator" do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
      expect { described_class.create(sint) }.to raise_error(described_class::Invalid)
    end

    it "returns the replicator registered with the given name" do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1")
      expect(described_class.create(sint)).to be_a(Webhookdb::Replicator::Fake)
    end

    it "searches plugins registered in replicator_ext" do
      fake_path = described_class::PLUGIN_DIR + "plugin_tester.rb"
      FileUtils.copy_file(test_data_dir + "plugin_tester.rb", fake_path.to_s)
      expect do
        described_class.registered!("plugin_tester")
      end.to raise_error(described_class::Invalid)
      described_class.load_replicators
      expect(described_class.registered!("plugin_tester").name).to eq("plugin_tester")
    ensure
      fake_path.unlink
    end
  end
end
