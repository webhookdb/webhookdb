# frozen_string_literal: true

require "webhookdb/postgres"

RSpec.describe Webhookdb::Postgres do
  # Since this spec tests model registration, save them before the tests run,
  # ensure that they're cleared before every test, then restore them after
  before(:all) do
    @original_superclasses = described_class.model_superclasses.dup
    @original_models = described_class.registered_models.dup
  end

  after(:all) do
    described_class.registered_models.replace(@original_models)
    described_class.model_superclasses.replace(@original_superclasses)
  end

  before(:each) do
    described_class.model_superclasses.clear
    described_class.registered_models.clear
  end

  it "provides a place for model superclasses to register themselves" do
    superclass = Class.new
    described_class.register_model_superclass(superclass)
    expect(described_class.model_superclasses).to include(superclass)
  end

  it "requires registered models immediately if any model superclass has a connection" do
    conn = instance_double(Sequel::Database)
    superclass = instance_double(Sequel::Model, db: conn)
    described_class.model_superclasses.add(superclass)

    expect(described_class).to receive(:require).with("spacemonkeys")
    described_class.register_model("spacemonkeys")

    expect(described_class.registered_models).to include("spacemonkeys")
  end

  it "defers requiring registered models if there are no model superclasses" do
    expect(described_class).to_not receive(:require)
    described_class.register_model("spacemonkeys")
    expect(described_class.registered_models).to include("spacemonkeys")
  end

  it "defers requiring registered models if no model superclass has a connection" do
    superclass = instance_double(Sequel::Model, db: nil)
    described_class.model_superclasses.add(superclass)

    expect(described_class).to_not receive(:require)
    described_class.register_model("spacemonkeys")

    expect(described_class.registered_models).to include("spacemonkeys")
  end

  it "can enumerate model classes" do
    superclass = Class.new
    described_class.register_model_superclass(superclass)
    sub = Class.new(superclass)
    arr = []
    described_class.each_model_class { |c| arr << c }
    expect(arr).to contain_exactly(sub)
  end

  describe "now_sql" do
    c = Sequel.connect("mock://")

    it "returns a delayed evaluation" do
      expect(described_class.now_sql).to be_a(Sequel::SQL::DelayedEvaluation)
    end

    it "returns a sql expression that evaluates to now" do
      Timecop.freeze("2020-10-30T00:00:00Z") do
        expect(c.select(described_class.now_sql).sql).to match(
          /SELECT CAST\('2020-10-\d\d \d\d:00:00\.000000' AS timestamptz\)/,
        )
      end
    end

    it "can use the given block" do
      expect(c.select(described_class.now_sql { "2022-01-01" }).sql).to eq("SELECT CAST('2022-01-01' AS timestamptz)")
    end
  end
end
