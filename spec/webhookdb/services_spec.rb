# frozen_string_literal: true

RSpec.describe Webhookdb::Services, :db do
  describe "looking up a service" do
    it "raises for an invalid service" do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "nope")
      expect { described_class.service_instance(sint) }.to raise_error(described_class::InvalidService)
    end

    it "returns the service instance registered with the given name" do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1")
      expect(described_class.service_instance(sint)).to be_a(Webhookdb::Services::Fake)
    end

    it "searches plugins registered in services_ext" do
      fake_path = described_class::PLUGIN_DIR + "plugin_tester.rb"
      FileUtils.copy_file(test_data_dir + "plugin_tester.rb", fake_path.to_s)
      expect do
        described_class.registered_service!("plugin_tester")
      end.to raise_error(described_class::InvalidService)
      described_class.load_services
      expect(described_class.registered_service!("plugin_tester").name).to eq("plugin_tester")
    ensure
      fake_path.unlink
    end
  end
end
