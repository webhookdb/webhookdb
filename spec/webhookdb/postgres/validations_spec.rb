# frozen_string_literal: true

require "webhookdb/postgres"
require "webhookdb/postgres/validations"

RSpec.describe Webhookdb::Postgres::Validations, :db do
  before(:all) do
    Sequel::Model.use_transactions = false
    Sequel::Model.cache_anonymous_models = false
    @subclasses = Webhookdb::Postgres::Model.subclasses.dup
  end

  after(:all) do
    Webhookdb::Postgres::Model.subclasses.replace(@subclasses)
    Sequel::Model.cache_anonymous_models = true
    Sequel::Model.use_transactions = true
  end

  let(:subclass) do
    mc = create_model(:validation_exclusive) do
      text :first_name
      text :last_name
      inet :ip
    end
    mc.class_eval do
      def self.name
        "Webhookdb::Exclusive"
      end
    end
    mc
  end

  let(:instance) { subclass.new }

  context "mutually exclusive" do
    it "can validate fields as mutually exclusive" do
      instance.first_name = "webhookdb"
      instance.last_name = "co"

      instance.validates_mutually_exclusive(:first_name, :last_name)

      expect(instance.errors).to include(:first_name)
      expect(instance.errors[:first_name].first).to match(/mutually exclusive/)
    end

    it "does not add errors if only one mutually exclusive field is set" do
      instance.first_name = "webhookdb"
      instance.last_name = nil

      expect do
        instance.validates_mutually_exclusive(:first_name, :last_name)
      end.to_not(change do
        instance.errors.count
      end)
    end
  end

  context "all or none" do
    it "validates that not all columns are set" do
      instance.last_name = "Curie"
      instance.validates_all_or_none(:first_name, :last_name)

      expect(instance.errors).to include(:first_name)
      expect(instance.errors[:first_name].first).to match(/must all be set or all be nil/)
    end

    it "passes validation if all of the passed columns are set" do
      instance.first_name = "Marie"
      instance.last_name = "Curie"

      expect do
        instance.validates_all_or_none(:first_name, :last_name)
      end.to_not(change do
        instance.errors.count
      end)
    end

    it "passes validation if none of the passed columns are set" do
      expect do
        instance.validates_all_or_none(:first_name, :last_name)
      end.to_not(change do
        instance.errors.count
      end)
    end
  end

  context "at least one of" do
    it "validates that at least one column is set" do
      instance.validates_at_least_one_of(:first_name, :last_name)

      expect(instance.errors).to include(:first_name)
      expect(instance.errors[:first_name].first).to match(/must be not nil/)
    end

    it "passes validation if one of the passed columns is set" do
      instance.last_name = "co"

      expect do
        instance.validates_at_least_one_of(:first_name, :last_name)
      end.to_not(change do
        instance.errors.count
      end)
    end
  end

  context "exactly one of" do
    it "validates that at least one column is set" do
      instance.validates_exactly_one_of(:first_name, :last_name)

      expect(instance.errors).to include(:first_name)
      expect(instance.errors[:first_name].first).to match(/must be not nil/)
    end

    it "validates that no more than one column is set" do
      instance.first_name = "webhookdb"
      instance.last_name = "co"

      instance.validates_exactly_one_of(:first_name, :last_name)

      expect(instance.errors).to include(:first_name)
      expect(instance.errors[:first_name].first).to match(/mutually exclusive/)
    end

    it "passes validation if only one of the columns is set" do
      instance.first_name = "webhookdb"
      instance.last_name = nil

      expect do
        instance.validates_exactly_one_of(:first_name, :last_name)
      end.to_not(change do
        instance.errors.count
      end)
    end
  end

  context "ip address" do
    let(:valid_ip) { "192.168.16.72" }
    let(:invalid_ip) { "284.111.0.1" }

    it "validates that the peer IP address is a valid INET address" do
      instance.ip = invalid_ip

      instance.validates_ip_address(:ip)

      expect(instance.errors).to include(:ip)
      expect(instance.errors[:ip].first).to match(/is not a valid INET address/i)
    end

    it "does not add errors if the IP address is a valid INET address" do
      instance.ip = valid_ip

      expect do
        instance.validates_ip_address(:ip)
      end.to_not(change do
        instance.errors.count
      end)
    end

    it "does not add errors if the IP address is already of type IPAddr" do
      instance.ip = IPAddr.new(valid_ip)

      expect do
        instance.validates_ip_address(:ip)
      end.to_not(change do
        instance.errors.count
      end)
    end
  end
end
