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

  describe "refers_to_same_index?" do
    opaqueid1 = Webhookdb::Id.new_opaque_id("svi")
    opaqueid2 = Webhookdb::Id.new_opaque_id("svi")

    it "is true if the tables and indices are the same" do
      idx1 = Sequel[:t1][:idx]
      idx2 = Sequel[:t1][:idx]
      expect(described_class.refers_to_same_index?(idx1, idx2)).to be(true)
    end

    it "is true if the tables and index names after the svi_ are the same" do
      idx1 = Sequel[:t1][:"#{opaqueid1}_at_idx"]
      idx2 = Sequel[:t1][:"#{opaqueid2}_at_idx"]
      expect(described_class.refers_to_same_index?(idx1, idx2)).to be(true)
    end

    it "is false if the index names after the svi_ are different" do
      idx1 = Sequel[:t1][:"#{opaqueid1}_at_idx"]
      idx2 = Sequel[:t1][:"#{opaqueid2}_ta_idx"]
      expect(described_class.refers_to_same_index?(idx1, idx2)).to be(false)
    end

    it "is false if the index names are different" do
      idx1 = Sequel[:t1][:idx1]
      idx2 = Sequel[:t1][:idx2]
      expect(described_class.refers_to_same_index?(idx1, idx2)).to be(false)
    end

    it "is false if the table names are different, even if the index names are the same" do
      idx1 = Sequel[:t1][:idx1]
      idx2 = Sequel[:t2][:idx1]
      expect(described_class.refers_to_same_index?(idx1, idx2)).to be(false)
    end
  end
end
