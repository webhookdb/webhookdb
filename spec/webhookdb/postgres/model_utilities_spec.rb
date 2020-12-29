# frozen_string_literal: true

require "webhookdb/postgres/model_utilities"

RSpec.describe Webhookdb::Postgres::ModelUtilities, "an extended class" do
  before(:all) do
    @real_superclasses = Webhookdb::Postgres.model_superclasses.dup
    @real_models = Webhookdb::Postgres.registered_models.dup
  end

  before(:each) do
    Webhookdb::Postgres.model_superclasses.clear
    Webhookdb::Postgres.registered_models.clear
  end

  after(:all) do
    Webhookdb::Postgres.model_superclasses.replace(@real_superclasses)
    Webhookdb::Postgres.registered_models.replace(@real_models)
  end

  let(:extended_class) do
    model_class = Class.new(Sequel::Model) do
      def self.slow_query_seconds
        1
      end
    end
    model_class.extend(Appydays::Loggable)
    model_class.extend(described_class)
    model_class.db = Sequel.connect("mock://postgres")
    model_class
  end

  RSpec::Matchers.define :be_included_in do |expected|
    match do |actual|
      expected.include?(actual)
    end
  end

  it "is registered as a model superclass" do
    expect(extended_class).to be_included_in(Webhookdb::Postgres.model_superclasses)
  end

  it "has a method to set the application name associated with the db" do
    expect(extended_class.db).to receive(:synchronize) do |&block|
      conn = instance_double(PG::Connection)
      expect(conn).to receive(:escape_string) do |string|
        string
      end
      expect(conn).to receive(:exec).
        with("SET application_name TO 'Webhookdb::Postgres::ModelUtilities Spec'")

      block.call(conn)
    end

    extended_class.appname = "Webhookdb::Postgres::ModelUtilities Spec"
  end

  it "has a method for fetching a subclass by its full name" do
    bogart_subclass = Class.new(extended_class) do
      def self.name
        "Webhookdb::Bogart"
      end
    end

    expect(extended_class.by_name("Bogart")).to be(bogart_subclass)
  end

  it "has a method for fetching its subclasses by an abbreviated name" do
    bansidhe_subclass = Class.new(extended_class) do
      def self.name
        "Webhookdb::Bansidhe"
      end
    end

    expect(extended_class.by_name("Webhookdb::Bansidhe")).to be(bansidhe_subclass)
  end
end
